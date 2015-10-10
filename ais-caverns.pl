#!/usr/bin/perl

# This is Jonadab's version, modified to be easier for a Perl
# programmer to understand.  I intend to get rid of all the bitwise
# arithmetic and stuff until I actually can follow what is going on.
# Otherwise I'll never be able to translate it into working C code.

# We have an 80x21 space. Each square in it starts out as undecided.

# Then we mark all the squares around the outside as wall.

# Then we visit all the other squares in a random order, converting
# them to wall or to floor. A square is a floor if it has two walls
# 8-next to it, which don't have a continuous 4-path of wall squares
# between them; and a wall if there are any adjacent walls
# otherwise. The remaining case is no walls; in that case, we choose
# at random.

# Afterward, a few areas of floor are converted into water or lava.

# We can also embed the Wizard's Tower or Fake Tower.

use warnings;
use strict;
use Term::ANSIColor;

my $width  = 79;
my $height = 20;

use constant FLOOR => 0;
use constant RIGHT => 1;
use constant UP => 2;
use constant LEFT => 4;
use constant DOWN => 8;
use constant CORRIDOR => 16;
use constant SOLID => 32;
use constant EDGE => 64;
use constant UNDECIDED => 128;
use constant WATER => 256;
use constant LAVA => 512;
use constant STAIR => 1024;

my @map;
my @coords;
my ($upstair, $dnstair);

my %arg;
my $depthfraction;
my $liqcount = 0;
my $river    = 0;
my $liquid;
my $dohtml = 0;

# Wall direction constants are 1=east, 2=north, 4=west, 8=south, and these
# are added together as appropriate to get combinations, so that for example
# if there are walls to the north and west, that's 6.
#                E N   W       S
#                                  1 1 1 1 1 1
#              0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
# that is to say, reading each column below as a binary number:
# south:       0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1
# west:        0 0 0 0 1 1 1 1 0 0 0 0 1 1 1 1
# north:       0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1
# east:        0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
my @walls = qw/! ─ │ └ ─ ─ ┘ ┴ │ ┌ │ ├ ┐ ┬ ┤ ┼
               ! ═ ║ ╚ ═ ═ ╝ ╩ ║ ╔ ║ ╠ ╗ ╦ ╣ ╬/;
# (The second batch, with the CORRIDOR bit (16) also set, are doors?)


while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg =~ /^([0-9.]+)$/) {
    $depthfraction = $arg;
  } elsif ($arg =~ /^(wiz|fake)tower\d$/) {
    $arg{embed}  = $arg;
  } elsif ($arg =~ /html/) {
    $dohtml = 1;
  } else {
    warn "Did not understand argument: $arg\n";
  }
}

$depthfraction = randomdepth() if not defined $depthfraction;
sub randomdepth {
  my $d = sprintf "%0.3f", (rand(100) / 100);
  print "Random Depth: $d\n";
  return $d;
}

generate_level();
show_level();
exit 0; # Subroutines follow.

# Returns the neighbours of a square.
sub neighbours {
  my ($x, $y) = @_;
  return (
          $map[$x+1][$y], $map[$x+1][$y+1], $map[$x][$y+1], $map[$x-1][$y+1],
          $map[$x-1][$y], $map[$x-1][$y-1], $map[$x][$y-1], $map[$x+1][$y-1]
         );
}

# Places a wall on a square, with side effects:
# - Dead ends are recursively removed;
# - Squares that do not form part of a 2x2 square become corridor.
sub block_point {
  my ($x, $y, $check, $mark_corridors) = @_;
  if ($x == 0 or $y == 0 or ($x == $width - 1) or ($y == $height - 1)) {
    return;
  }
  if ($check and ($map[$x][$y] eq SOLID)) {
    return;
  }

  my $wallcount =
    (($map[$x+1][$y] eq SOLID) ? 1 : 0) +
    (($map[$x][$y+1] eq SOLID) ? 1 : 0) +
    (($map[$x-1][$y] eq SOLID) ? 1 : 0) +
    (($map[$x][$y-1] eq SOLID) ? 1 : 0);

  if ($wallcount == 3 or not $check) {
    $map[$x][$y] = SOLID;
    block_point($x+1, $y, 1, $mark_corridors);
    block_point($x, $y+1, 1, $mark_corridors);
    block_point($x-1, $y, 1, $mark_corridors);
    block_point($x, $y-1, 1, $mark_corridors);
    if ($mark_corridors) {
      block_point($x+1, $y+1, 1, $mark_corridors);
      block_point($x+1, $y-1, 1, $mark_corridors);
      block_point($x-1, $y+1, 1, $mark_corridors);
      block_point($x-1, $y-1, 1, $mark_corridors);
    }
  }
  if ($mark_corridors
      and ($map[$x][$y] ne SOLID)
      and ($map[$x][$y] ne CORRIDOR)) {
    my @neighbours = neighbours($x, $y);
    $map[$x][$y] = CORRIDOR;
    for my $nidx (0, 2, 4, 6) {
      if (($map[$x][$y] eq CORRIDOR)
          and not (($neighbours[$nidx] eq SOLID) or
                   ($neighbours[($nidx + 1) % 8] eq SOLID) or
                   ($neighbours[($nidx + 2) % 8] eq SOLID))) {
          $map[$x][$y] = FLOOR;
      }
    }
  }
}

sub markwalldirs {
  my ($x, $y, $add, $subtract) = @_;
  if ($map[$x][$y] ne FLOOR) {
    # FLOOR is the only exception because CORRIDOR can mean door.
    for my $dir (@$add) {
      $map[$x][$y] |= $dir;
    }
    for my $dir (@$subtract) {
      $map[$x][$y] &= ~$dir;
    }
  }
}

sub placestairs {
  my ($trycount) = @_;
  ++$trycount;
  my $stairx = 1;
  my @shuffy = (1 .. ($height - 1));
  # Base stair-placement probabability.  High values tend to give you
  # stairs very near the left and right edges, so you have to cross
  # the whole map.  Low values can give you stairs pretty much
  # anywhere.  We want each of these scenarios to happen frequently.
  my $baseprob = int(rand(5) * rand(6));
  warn "baseprob: $baseprob\n";
  my $prob = $baseprob;
  for my $i (0 .. ($height - 2)) {
    my $swapi = int rand($height - 2);
    my $swap  = $shuffy[$i];
    $shuffy[$i] = $shuffy[$swapi];
    $shuffy[$swapi] = $swap;
  }
  while ($prob++ <= 2000 and not $upstair) {
    while ($stairx < $width and not $upstair) {
      #warn "shuffy: " . (join " ", map { qq['$_'] } @shuffy) . "\n";
      for my $stairy (@shuffy) {
        if (($map[$stairx][$stairy] eq FLOOR) and not $upstair
            and ($prob >= rand 1000)) {
          $map[$stairx][$stairy] = STAIR;
          $upstair = +{ x => $stairx, y => $stairy};
        }
      }
      $stairx++;
    }
  }
  # Reshuffle the y order for doing the other stairs:
  for my $i (0 .. ($height - 2)) {
    my $swapi = int rand($height - 2);
    my $swap  = $shuffy[$i];
    $shuffy[$i] = $shuffy[$swapi];
    $shuffy[$swapi] = $swap;
  }
  $stairx = $width - 1;
  $prob = $baseprob;
  while ($prob++ <= 2000 and not $dnstair) {
    while (($stairx > 0) and not $dnstair) {
      for my $stairy (@shuffy) {
        if (($map[$stairx][$stairy] eq FLOOR) and not $dnstair
            and ($prob >= rand 1000)) {
          $map[$stairx][$stairy] = STAIR;
          $dnstair = +{ x => $stairx, y => $stairy };
        }
      }
      $stairx--;
    }
  }
  if ($trycount < 1000 and not ($upstair and $dnstair)) {
    placestairs();
  }
}

sub generate_level {

  # Initialize to undecided...
  for my $x (0 .. ($width - 1)) {
    for my $y (0 .. ($height - 1)) {
      if ($x == 0 || $y == 0 || ($x == $width - 1) || ($y == $height - 1)) {
        $map[$x][$y] = SOLID;
      } else {
        $map[$x][$y] = UNDECIDED;
        push @coords, [$x, $y];
      }
    }
  }

  # Shuffle the coordinates.
  my @shuffled_coords;
  while (@coords) {
    my $index = int(rand(@coords));
    push @shuffled_coords, splice @coords, $index, 1;
  }

  doembed($arg{embed}) if $arg{embed};

  for my $cpair (@shuffled_coords) {
    my ($x, $y) = @$cpair;
    if ($map[$x][$y] eq UNDECIDED) {

      my @neighbours = neighbours($x, $y);

      # To reduce diagonal chokepoints, we treat any diagonally adjacent spot
      # between two walls as a floor.
      for my $nidx (0, 2, 4, 6) {
        if (($neighbours[$nidx] eq SOLID) and
            ($neighbours[($nidx + 2) % 8] eq SOLID) and
            ($neighbours[$nidx + 1] eq SOLID)) {
          $neighbours[$nidx + 1] = FLOOR;
        }
      }

      my $transitioncount = 0;
      for my $nidx (0 .. 7) {
        $transitioncount += (($neighbours[$nidx] eq SOLID) xor
                             ($neighbours[($nidx+1) % 8] eq SOLID));
      }

      my $newval = $transitioncount > 2 ? FLOOR :
                   $transitioncount == 2 ? SOLID :
                   ((rand 1) < ($depthfraction *
                                $depthfraction *
                                $depthfraction)) ? SOLID : FLOOR;

      # In order to get larger blocks of walls, if we just created a dead end,
      # we mark that cell as # even if it was previously ., because we know
      # that doing that cannot block connectivity.
      $map[$x][$y] = $newval;
      if ($newval eq SOLID) {
        block_point($x, $y, 0, 0);
      }
    }
  }

  # Now remove orphaned walls from the map.
  for my $x (1 .. ($width - 2)) {
    for my $y (1 .. ($height - 2)) {
      if (($map[$x+1][$y] ne SOLID) and
          ($map[$x-1][$y] ne SOLID) and
          ($map[$x][$y+1] ne SOLID) and
          ($map[$x][$y-1] ne SOLID) and
          ($map[$x][$y] eq SOLID)) {
        $map[$x][$y] = FLOOR;
      }
    }
  }

  # Mark corridors on the map.
  for my $x (1 .. ($width - 2)) {
    for my $y (1 .. ($height - 2)) {
      block_point $x, $y, 1, 1;
    }
  }

  if (rand(100) > 50) {
    # To produce longer corridors, we block any squares that are diagonally
    # adjacent to a corridor, but not orthogonally adjacent to a corridor or
    # which have both squares a knight's move from the corridor open.
    my $anychanges = 1;
    while ($anychanges) {
      $anychanges = 0;
      for my $cpair (@shuffled_coords) {
        my ($x, $y) = @$cpair;
        my $orthocorridor = 0;
        my @neighbours = neighbours($x, $y);
        next if (($map[$x][$y] eq SOLID) or
                 ($map[$x][$y] eq CORRIDOR));
        for my $nidx (0, 2, 4, 6) {
          if ($neighbours[$nidx] eq CORRIDOR) {
            $orthocorridor++;
          }
        }
        if ($orthocorridor == 0) {
          for my $nidx (1, 3, 5, 7) {
            if (($neighbours[$nidx] eq CORRIDOR) and
                (($neighbours[($nidx + 3) % 8] eq SOLID) or
                 ($neighbours[($nidx + 3) % 8] eq CORRIDOR) or
                 ($neighbours[($nidx + 5) % 8] eq SOLID) or
                 ($neighbours[($nidx + 5) % 8] eq CORRIDOR))) {
              ($anychanges = 1);
              block_point($x, $y, 0, 1);
            }
          }
        }
      }
    }
  }

  # If a corridor has a length of exactly 2, convert it back to room squares.
  # This looks neater than the alternative, although the effect is minor.
  for my $x (1 .. ($width - 2)) {
    for my $y (1 .. ($height - 2)) {
      if ($map[$x][$y] ne CORRIDOR) {
        for my $d ([0,+1],[0,-1],[+1,0],[-1,0]) {
          my ($d1, $d2) = @$d;
          if (not ((($x == ($width - 2)) and ($d1 == 1)) or
                   (($y == ($height - 2)) and ($d2 == 1)) or
                   (($x == 1) and ($d1 == -1)) or
                   (($y == 1) and ($d2 == -1))) and
              not ($map[$x+$d1][$y+$d2] eq CORRIDOR) and
              not (($map[$x+2*$d1][$y+2*$d2] eq CORRIDOR) or
                   ($map[$x+$d1+$d2][$y+$d1+$d2] eq CORRIDOR) or
                   ($map[$x+$d1-$d2][$y-$d1+$d2] eq CORRIDOR) or
                   ($map[$x+$d2][$y+$d1] eq CORRIDOR) or
                   ($map[$x-$d2][$y-$d1] eq CORRIDOR) or
                   ($map[$x-$d1][$y-$d2] eq CORRIDOR))) {
            if ($map[$x][$y] eq CORRIDOR) {
              $map[$x][$y] = FLOOR;
            }
            if ($map[$x+$d1][$y+$d2] eq CORRIDOR) {
              $map[$x+$d1][$y+$d2] = FLOOR;
            }
          }
        }
      }
    }
  }

  # Repeat the embed, undoing any of the above changes in that area.
  doembed($arg{embed}) if $arg{embed};

  # Work out where walls should be. We start by drawing a square around every
  # open floor space, then remove the parts of the square that do not connect
  # to other walls.

  # I am leaving some bitwise arithmetic in this section of the code
  # because unlike with all that gratuitous &= ~CORRIDOR garbage
  # earlier, here there is an actual reason for it to be this way.

  # Wall directions:
  # Add the wall dirs needed so that floor areas are surrounded:
  $walls[0] = ' ';
  for my $x (1 .. ($width - 2)) {
    for my $y (1 .. ($height - 2)) {
      if ($map[$x][$y] eq FLOOR) {
        markwalldirs($x+1, $y, [UP, DOWN]);
        markwalldirs($x-1, $y, [UP, DOWN]);
        markwalldirs($x, $y+1, [LEFT, RIGHT]);
        markwalldirs($x, $y-1, [LEFT, RIGHT]);
        markwalldirs($x+1, $y+1, [UP, LEFT]);
        markwalldirs($x-1, $y+1, [UP, RIGHT]);
        markwalldirs($x+1, $y-1, [DOWN, LEFT]);
        markwalldirs($x-1, $y-1, [DOWN, RIGHT]);
      }
    }
  }
  # Wall directions:
  # Subtract wall dirs that would point straight into floor areas:
  for my $x (0 .. ($width - 1)) {
    for my $y (0 .. ($height - 1)) {
      if (($x < $width - 1) and not
          ($map[$x+1][$y] & (SOLID | CORRIDOR))) {
        markwalldirs($x, $y, undef, [RIGHT]);
      }
      if (($x > 0) and not
          ($map[$x-1][$y] & (SOLID | CORRIDOR))) {
        markwalldirs($x, $y, undef, [LEFT]);
      }
      if (($y < $height - 1) and not
          ($map[$x][$y+1] & (SOLID | CORRIDOR))) {
        markwalldirs($x, $y, undef, [DOWN]);
      }
      if (($y > 0) and not
          ($map[$x][$y-1] & (SOLID | CORRIDOR))) {
        markwalldirs($x, $y, undef, [UP]);
      }
    }
  }

  # Make corridors on walls secret if it doesn't create an obvious dead
  # end (it usually does). The exception is dug-out corner squares,
  # which are converted to diagonal chokepoints instead.
  for my $cpair (@shuffled_coords) {
    my ($x, $y) = @$cpair;
    if ($map[$x][$y] & CORRIDOR) {
      my @neighbours = neighbours $x, $y;
      my $checklonely = 1;
      for my $nidx (0, 2, 4, 6) {
        if ($neighbours[$nidx] & CORRIDOR) {
          $checklonely = 0;
        }
      }
      if ($checklonely) {
        $map[$x][$y] |= SOLID;
        if ((($map[$x][$y] & UP) or
             ($map[$x][$y] & DOWN)) and
            (($map[$x][$y] & LEFT) or
             ($map[$x][$y] & RIGHT))) {
          if ($map[$x][$y] & CORRIDOR) {
            # This almost never happens.
            $map[$x][$y] = FLOOR;
          }
        }

        my $corridorcount = 0;
        for my $nidx (0, 2, 4, 6) {
          if ($neighbours[$nidx] & CORRIDOR and
              not ($neighbours[$nidx] & SOLID)) {
            $corridorcount++;
          }
        }

        if ($corridorcount >= 3) {
          if (($map[$x+1][$y] & (CORRIDOR | 15)) == (CORRIDOR | UP | DOWN)
              and $map[$x+1][$y+1] & SOLID and $map[$x+1][$y-1] & SOLID) {
            $map[$x+1][$y] |= SOLID;
          } elsif (($map[$x-1][$y] & (CORRIDOR | 15)) == (CORRIDOR | UP | DOWN)
                   and $map[$x-1][$y+1] & SOLID and $map[$x-1][$y-1] & SOLID) {
            $map[$x-1][$y] |= SOLID;
          } elsif (($map[$x][$y+1] & (CORRIDOR | 15)) == (CORRIDOR | LEFT | RIGHT)
                   and $map[$x+1][$y+1] & SOLID and $map[$x-1][$y+1] & SOLID) {
            $map[$x][$y+1] |= SOLID;
          } elsif (($map[$x][$y-1] & (CORRIDOR | 15)) == (CORRIDOR | LEFT | RIGHT)
                   and $map[$x+1][$y-1] & SOLID and $map[$x-1][$y-1] & SOLID) {
            $map[$x][$y-1] |= SOLID;
          }
        }
      }
    }
  }

  ## Meh, this part isn't actually needed.
  ##  # Also make the entire corridor secret if it doesn't branch and ends cleanly
  ##  # at each end.
  ##  sub cleanly_ending_corridor {
  ##      my ($x, $y) = @_;
  ##      if (not $map[$x][$y] & CORRIDOR) {
  ##        return;
  ##      }
  ##      if ($map[$x][$y] & SOLID) {
  ##        # It's a secret door.  That counts as a clean end.
  ##        return 1;
  ##      }
  ##      my @neighbours = neighbours($x, $y);
  ##      my $corridorcount = 0;
  ##      for my $nidx (0, 2, 4, 6) {
  ##        if ($neighbours[$nidx] & CORRIDOR) {
  ##          $corridorcount++;
  ##        }
  ##      }
  ##      return if $corridorcount != 1;
  ##      return if $map[$x][$y] & LEFT && $map[$x-1][$y] & CORRIDOR;
  ##      return if $map[$x][$y] & RIGHT && $map[$x+1][$y] & CORRIDOR;
  ##      return if $map[$x][$y] & UP && $map[$x][$y-1] & CORRIDOR;
  ##      return if $map[$x][$y] & DOWN && $map[$x][$y+1] & CORRIDOR;
  ##      return 1;
  ##  }
  ##  sub mark_corridor_secret {
  ##      my ($x, $y, $ox, $oy) = @_;
  ##      $map[$x][$y] & CORRIDOR or return 0;
  ##      $map[$x][$y] & SOLID and return 0;
  ##      my @neighbours = neighbours $x, $y;
  ##      my $opencount = 0;
  ##      $neighbours[$_] & SOLID or $opencount++ for (0, 2, 4, 6);
  ##      $opencount > 2 and return 0;
  ##      if ($ox != -1 && cleanly_ending_corridor $x, $y) {
  ##          $map[$x][$y] |= SOLID;
  ##          return 1;
  ##      }
  ##      my $a = 0;
  ##      $a += mark_corridor_secret($x+1, $y, $x, $y)
  ##          unless $ox == $x+1 && $oy == $y or $a;
  ##      $a += mark_corridor_secret($x-1, $y, $x, $y)
  ##          unless $ox == $x-1 && $oy == $y or $a;
  ##      $a += mark_corridor_secret($x, $y+1, $x, $y)
  ##          unless $ox == $x && $oy == $y+1 or $a;
  ##      $a += mark_corridor_secret($x, $y-1, $x, $y)
  ##          unless $ox == $x && $oy == $y-1 or $a;
  ##      return $a;
  ##  }
  ##  for my $x (0 .. ($width - 1)) {
  ##      for my $y (0 .. ($height - 1)) {
  ##          next unless cleanly_ending_corridor $x, $y;
  ##          if (mark_corridor_secret $x, $y, -1, -1) {
  ##              $map[$x][$y] |= SOLID;
  ##          }
  ##      }
  ##  }

  # Before laying down liquids, reserve space for the stairs...
  placestairs();

  $liquid   = ($depthfraction > (rand(100) / 90)) ? LAVA : WATER;
  if (2 > int rand($depthfraction * 100)) {
    $river = 1;
    my $minbreadth = 1 + rand 1;
    my $cx = ($width / 4) + rand($width / 2);
    my ($cy, $cydir, $cxdir) = (0, 1, 0);
    if (50 < int rand 100) {
      ($cy, $cydir) = ($height - 1, -1);
    }
    for (0 .. $height) {
      my $hflex = $minbreadth * 1.5;
      if ($cx / $width > 0.9) {
        $cx += $hflex - rand $hflex;
        $cxdir = -2;
      } elsif ($cx / $width < 0.1) {
        $cx += (rand $hflex) - $hflex;
        $cxdir = 2;
      } elsif (abs($cxdir) > $minbreadth * 2) {
        $cxdir = $cxdir * rand 1;
        $cx += $cxdir;
      } else {
        $cxdir += $hflex - rand($hflex * 2);
        $cx += $cxdir;
      }
      dopool($cx, $cy, $minbreadth + rand $minbreadth, 0);
      $cy += $cydir;
    }
  } else {
    for (1 .. int((rand(6) * rand($depthfraction * 8)) - 1.5)) {
      $liqcount++;
      my $cx = int rand $width;
      my $cy = int rand $height;
      my $radius  = 2 + rand rand rand 7;
      dopool($cx, $cy, $radius);
    }}
}

sub show_level {

  my $plural = ($liqcount > 1) ? "s" : '';
  my $liquidcount = $river ? "(river of " . ($liquid eq LAVA ? "lava" : "water") . ")"
    : $liqcount ? "($liqcount pool$plural of " . ($liquid eq LAVA ? "lava" : "water") . ")"
    : "(No liquid)";

  open HTML, ">>", "gehennom-maps.html" if $dohtml;

  print HTML qq[<div class="dungeon">
<div class="dungeondepth">Depth Fraction: $depthfraction</div>\n] if $dohtml;

  print HTML qq[<div class="liquidcount">$liquidcount</div>\n] if $dohtml;
  print $liquidcount . "\n";

  print HTML qq[<div class="dungeonmap">\n] if $dohtml;
  for my $y (0 .. ($height - 1)) {
    print HTML qq[  <div class="dungeonrow">] if $dohtml;
    for my $x (0 .. ($width - 1)) {
      if ($map[$x][$y] & STAIR) {
        print HTML qq[<span class="stair">] if $dohtml;
        print color 'bold white on_red';
      } elsif (($map[$x][$y] & (SOLID)) and ($map[$x][$y] & (CORRIDOR))) {
        print HTML qq[<span class="secretcorr">] if $dohtml;
        print color 'blue';
      } elsif ($map[$x][$y] & (SOLID)) {
        print HTML qq[<span class="wall">] if $dohtml;
        print color 'red';
      } elsif ($map[$x][$y] & LAVA) {
        print HTML qq[<span class="lava">] if $dohtml;
        print color 'bold yellow on_red';
      } elsif ($map[$x][$y] & WATER) {
        print HTML qq[<span class="water">] if $dohtml;
        print color 'bold cyan on_blue';
      } elsif (($map[$x][$y] & CORRIDOR) and
               ($map[$x][$y] & SOLID)) {
        print HTML qq[<span class="secretcorridor">] if $dohtml;
        print color 'blue';
      } elsif ($map[$x][$y] & (CORRIDOR)) {
        print HTML qq[<span class="corridor">] if $dohtml;
        print color 'bold black';
      } else {
        print HTML qq[<span class="floor">] if $dohtml;
        print color 'white' ;
      }
      print(
        (($map[$x][$y] & (SOLID)) and ($map[$x][$y] & (CORRIDOR))) ? "#" :
        (($x == $$upstair{x}) and ($y == $$upstair{y})) ? "<" :
        (($x == $$dnstair{x}) and ($y == $$dnstair{y})) ? ">" :
        $map[$x][$y] & SOLID ? $walls[$map[$x][$y] & 31] :
          $map[$x][$y] & (WATER | LAVA) ? '}' :
            $map[$x][$y] & CORRIDOR ? '#' : '.');
      print color 'reset';
      my $wallchar = $walls[$map[$x][$y] & 31]; $wallchar =~ s/ /&nbsp;/;
      if ($dohtml) {
        print HTML (
                    (($map[$x][$y] & (SOLID)) and ($map[$x][$y] & (CORRIDOR))) ? "#" :
                    (($x == $$upstair{x}) and ($y == $$upstair{y})) ? "&lt;" :
                    (($x == $$dnstair{x}) and ($y == $$dnstair{y})) ? "&gt;" :
                    $map[$x][$y] & SOLID ? $wallchar :
                    $map[$x][$y] & (WATER | LAVA) ? '}' :
                    $map[$x][$y] & CORRIDOR ? '#' : '.');
        print HTML "</span>";
      }
    }
    print HTML "</div>\n" if $dohtml;
    print "\n";
  }
  print HTML "</div></div>\n\n" if $dohtml;
}

sub dopool {
  my ($cx, $cy, $radius, $jitter) = @_;
  my $stretch      = 1 + ((rand 50) / 100);
  my $eatrockpct ||= 0;
  $jitter        ||= (rand 50) / 20;
  for my $x (($cx - $radius * $stretch) .. ($cx + $radius * $stretch)) {
    if (($x > 0) and ($x + 1 < $width)) {
      for my $y (($cy - $radius) .. ($cy + $radius)) {
        if (($y > 0) and ($y + 1 < $height)) {
          my $distance = sqrt((($x - $cx) / $stretch)**2 + ($y - $cy) ** 2) + rand $jitter;
          if (($distance <= $radius) and
              (not ($map[int $x][int $y] & STAIR)) and
              ((not ($map[int $x][int $y] & SOLID))
                and (not ($map[int $x][int $y] & CORRIDOR)))) {
            $map[int $x][int $y] = $liquid;
          }}}}}
}

sub embedcenter {
  my (@e) = @_; # The embed is assumed to be rectangular.  (But, it can contain undecided terrain.)
  my $x = int(($width - scalar @{$e[0]}) / 2);
  my $y = int(($height - scalar @e) / 2);
  return ($x, $y);
}

sub placeembed {
  my ($e, $xoffset, $yoffset) = @_;
  my $dy = 0;
  for my $line (@$e) {
    my $dx = 0;
    for my $tile (@$line) {
      $map[$xoffset + $dx][$yoffset + $dy] = $tile;
      $dx++;
    }
    $dy++;
  }
}

sub parseembed {
  return map {
    [ map {
      my $char = $_;
      my $tile = UNDECIDED;
      if ($char =~ /[-|]/) {
        $tile = SOLID;
      } elsif ($char eq ' ') {
        $tile = SOLID;
      } elsif ($char eq '.') {
        $tile = FLOOR;
      } elsif ($char eq 'S') {
        $tile = (SOLID | CORRIDOR);
      } elsif ($char eq '?') {
        $tile = UNDECIDED;
      } elsif ($char eq 'L') {
        $tile = LAVA;
      } elsif ($char eq 'W') {
        $tile = WATER;
      }
      $tile;
    } split //, $_]
  } @_;
}

sub doembed {
  my ($special) = @_;
  my @embed = ([]);
  if ($special eq 'wiztower1') {
    print "Wizard's Tower, Bottom Level\n";
    @embed = parseembed(' --------------------- ',
                        ' |...................| ',
                        ' |--S------------....| ',
                        ' |....|.WWWWWWW.|--S-| ',
                        ' |....|.WW   WW.|....| ',
                        ' |....|.W  .  W.|....| ',
                        ' |-S--|.W ... W.|....| ',
                        ' |....|.W  .  W.|....| ',
                        ' |....S.WW   WW.|....| ',
                        ' |....|.WWWWWWW.|....| ',
                        ' --------------------- ');
  } elsif ($special eq 'wiztower2') {
    print "Wizard's Tower, Middle Level\n";
    @embed = parseembed('---------------------',
                        '|....|..............|',
                        '|-S--|-S----------S-|',
                        '|..|.|.........|....|',
                        '|..S.|.........|-S--|',
                        '|..|.|.........|....|',
                        '|S--S|.........|....|',
                        '|....|.........|--S-|',
                        '|....S.........|....|',
                        '|....|.........|....|',
                        '---------------------');
  } elsif ($special eq 'wiztower3') {
    print "Wizard's Tower, Top Level\n";
    @embed = parseembed('---------------------',
                        '|....S.......S......|',
                        '|....|-----------S--|',
                        '|....|WWWWWWW|......|',
                        '|....|WW---WW|......|',
                        '|....|W--.--W|......|',
                        '|--S-|W|...|W|----S-|',
                        '|....|W--.--W|......|',
                        '|....|WW---WWS......|',
                        '|....|WWWWWWW|......|',
                        '---------------------');
  } elsif ($special eq 'faketower1') {
    print "Fake Tower One\n";
    @embed = parseembed('WWWWWWW',
                        'WW---WW',
                        'W--.--W',
                        'W|...|W',
                        'W--.--W',
                        'WW---WW',
                        'WWWWWWW');
  } elsif ($special eq 'faketower2') {
    print "Fake Tower Two\n";
    @embed = parseembed('WWWWWWW',
                        'WW---WW',
                        'W--.--W',
                        'W|...|W',
                        'W--.--W',
                        'WW---WW',
                        'WWWWWWW');
  }
  my ($xoffset, $yoffset) = embedcenter(@embed);
  placeembed([@embed], $xoffset, $yoffset);
}


