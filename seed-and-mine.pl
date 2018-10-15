#!/usr/bin/perl

use strict;
use Term::ANSIColor;
use Carp;

my %cmdarg = @ARGV;
my $domonsters = 0; # for now
my $reset = chr(27) . qq{[0m};

my ($ROWNO, $COLNO) = (($cmdarg{ROWNO} || 21), ($cmdarg{COLNO} || 79));
my $depth = 3 + $cmdarg{depth} || int rand 12;

my $corr  = +{ t => 'CORR',
               b => 'on_black',
               f => 'white',
               c => '#',
             };
my $ecorr = $corr;
my $scorr = +{ t => 'CORR',
               b => 'on_black',
               f => 'blue',
               c => '#',
             };
sub roomfloor {
  my ($roomno) = @_;
  return +{
           t => 'ROOM',
           b => 'on_black',
           f => 'white',
           c => '·',
           r => $roomno,
          };
}
my $floor = +{ t => 'ROOM',
               b => 'on_black',
               f => 'white',
               c => '·',
             };
# Some colored floors for debugging purposes:
my $redfloor = +{ t => 'ROOM',
               b => 'on_black',
               f => 'red',
               c => '·',
             };
my $bluefloor = +{ t => 'ROOM',
               b => 'on_black',
               f => 'blue',
               c => '·',
             };
my $greenfloor = +{ t => 'ROOM',
                    b => 'on_black',
                    f => 'green',
                    c => '.',
             };
my $stone = +{ c => ' ',
               b => 'on_black',
               f => 'white',
               t => 'STONE',
             };
my $door  = +{ c => '+',
               b => 'on_black',
               f => 'yellow',
               t => 'DOOR' };
my $sdoor = +{ c => '+',
               b => 'on_black',
               f => 'blue',
               t => 'DOOR' };
my $hwall = +{ c => '-',
               b => 'on_black',
               f => 'white',
               t => 'WALL' };
my $vwall = +{ c => '|',
               b => 'on_black',
               f => 'white',
               t => 'WALL' };

my %wdir = ( E => +{ bit => 1, dx =>  1, dy =>  0, clockwise => 'S', },
             N => +{ bit => 2, dx =>  0, dy => -1, clockwise => 'E', },
             W => +{ bit => 4, dx => -1, dy =>  0, clockwise => 'N', },
             S => +{ bit => 8, dx =>  0, dy =>  1, clockwise => 'W', },
           );
my @wallglyph = qw/! ─ │ └ ─ ─ ┘ ┴ │ ┌ │ ├ ┐ ┬ ┤ ┼/;
$wallglyph[0] = '-';


# We start with solid rock:
my @map = (map {
  [ map { $stone } 0 .. $ROWNO ],
} 0 .. $COLNO);

# Then we mineralize it.  We aren't going to put any minerals in the
# edges, so we have available a rectangle with x coords from 1 to
# ($COLNO - 1) and y coords from 1 to ($ROWNO - 1).
my @mineral = ( (+{ c => '$',
                    f => 'bold yellow',
                    n => "gold" }) x 10,
                (map { +{ c => '*',
                          f => "bold $_",
                          n => "worthless piece of $_ glass",
                        }
                     } qw(red blue green white yellow cyan magenta)),
              );
my $availabletiles = ($COLNO - 1) * ($ROWNO - 1);
my $totalminerals  = 0;
for (1 .. (int($availabletiles / 3) + int rand($availabletiles / 13))) {
  my $x = 1 + int rand($COLNO - 1);
  my $y = 1 + int rand($ROWNO - 1);
  if (not $map[$x][$y]{m}) {
    $totalminerals++;
    $map[$x][$y] = +{ %{$map[$x][$y]},
                      m => $mineral[rand @mineral],
                    };
  }}

# Now we mine out a percentage of the minerals, depending on depth.
my $startx = int(($COLNO / 4) + rand($COLNO / 2));
my $starty = int(($ROWNO / 4) + rand($ROWNO / 2));
$map[$startx][$starty] = $floor;
my @initialgoal = (+{ x => 1 + int(rand($COLNO / 2)),      y => 1 + int(rand($ROWNO / 2)), },
                   +{ x => $COLNO - int(rand($COLNO / 2)), y => $ROWNO - int(rand($ROWNO / 2)), },
                   +{ x => 1 + int(rand ($COLNO / 2)),     y => $ROWNO - int(rand($ROWNO / 2)), },
                   +{ x => $COLNO - int(rand($COLNO / 2)), y => 1 + int(rand($ROWNO / 2)), },
                   +{ x => 1 + int(rand $COLNO),           y => 1 + int(rand $ROWNO), },
                     );
my @miner = map { +{ x => $startx,
                     y => $starty,
                     goal  => shift @initialgoal,
                     path  => [],
                     found => [],
                   } } 1 .. 4;
my $minedminerals = 0;
my @direction = ([1,0],[-1,0],[0,1],[0,-1],[-1,-1],[1,1],[-1,1],[1,-1]);
while ($minedminerals < ((18 + $depth) * $totalminerals / 50)) {
  for my $m (@miner) {
    # Pick a nearby mineral to try to reach:
    my $dist = 0;
    if (not $$m{goal}) {
      my @cpos = ();
      while ((8 >= scalar @cpos) or (($dist > 5) and (not @cpos))) {
        $dist++;
        for my $xdist (0 .. $dist) {
          my $ydist = $dist - $xdist;
          for my $p (+{ x => $$m{x} + $xdist, y => $$m{y} + $ydist},
                     +{ x => $$m{x} + $xdist, y => $$m{y} - $ydist},
                     +{ x => $$m{x} - $xdist, y => $$m{y} - $ydist},
                     +{ x => $$m{x} - $xdist, y => $$m{y} + $ydist}) {
            push @cpos, $p
              if (($$p{x} >= 1) and ($$p{x} < $COLNO) and
                  ($$p{y} >= 1) and ($$p{y} < $ROWNO) and
                  $map[$$p{x}][$$p{y}]{m});
          }}}
      #use Data::Dumper; print Dumper(\@cpos);
      # Weight it so that ones further from the nearest edge are more likely:
      my $greatestdist = 0;
      @cpos = map {
        my $p = $_;
        # How far is the nearest edge?
        my $xdist = ($$p{x} > ($COLNO / 2)) ? $COLNO - $$p{x} : $$p{x};
        my $ydist = ($$p{y} > ($ROWNO / 2)) ? $ROWNO - $$p{y} : $$p{y};
        my $thisdist = ($xdist > $ydist) ? $ydist : $xdist;
        $greatestdist = $dist if $thisdist > $greatestdist;
        [$p => $thisdist];
      } @cpos;
      #use Data::Dumper; print Dumper(\@cpos);
      @cpos = map {
        my ($p, $d) = @$_;
        my $n = 1 + ($greatestdist - $d) * ($greatestdist - $d); # smaller if $dist is bigger.
        ($p) x $n; # bigger $dist means smaller $n means fewer copies, lower odds of being picked.
      } @cpos;
      #use Data::Dumper; print Dumper(\@cpos); exit 0;
      $$m{goal} = $cpos[rand @cpos];
    }
    my ($x, $y) = ($$m{x}, $$m{y});
    if (45 > rand 100) {
      $x += ($$m{goal}{x} <=> $$m{x});
    } else {
      $y += ($$m{goal}{y} <=> $$m{y});
    }
    if ($map[$x][$y]{t} eq 'STONE') { # mine out this tile
      if ($map[$x][$y]{m}) {
        $minedminerals++;
        push @{$$m{found}}, +{ x => $x, y => $y, m => $map[$x][$y]{m} };
      }
      $map[$x][$y] = $corr;
    }
    push @{$$m{path}}, +{ x => $x, y => $y };
    $$m{x} = $x;  $$m{y} = $y;
    if (($$m{goal}{x} == $$m{x}) and ($$m{goal}{y} == $$m{y})) {
      $$m{goal} = undef;
    }
  }
  if (not ($minedminerals % 4)) {
    showmap();
    select undef, undef, undef, 0.1;
  }
}
# Replace corridors with floor where appropriate:
for my $x (0 .. $COLNO) {
  for my $y (0 .. $ROWNO) {
    if ($map[$x][$y]{t} eq 'CORR') {
      my $snc = solidneighborcount($x, $y);
      if ($snc < 6) {
        $map[$x][$y] = $floor;
      }
    }
  }
}

# Final Cleanup:
my $anychanges = 1;
while ($anychanges) {
  $anychanges = 0;
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      my $snc = solidneighborcount($x, $y, 1, 1, 1);
      if (($map[$x][$y]{t} eq 'WALL') and
          ($snc == 8)) {
        $anychanges++;
        $map[$x][$y] = $stone;
      } elsif (($map[$x][$y]{t} eq 'STONE') and
               ($snc < 8)) {
          $map[$x][$y] = $hwall;
      }
      if ($map[$x][$y]{t} eq 'CORR') {
        my $ofc = orthogonalfloorcount($x, $y);
        if ($ofc >= 3) {
          $map[$x][$y] = $floor;
          $anychanges++;
          #} elsif (($ofc == 1) and
          #         solidneighborcount($x,$y,0,0,0) <= 5) {
          #  $map[$x][$y] = $door;
        }
        for my $dirone (keys %wdir) {
          my $dirtwo = $wdir{$dirone}{clockwise};
          my $none = neighbor($x, $y, $dirone);
          my $ntwo = neighbor($x, $y, $dirtwo);
          if ($none and $ntwo and
              ($$none{t} eq 'ROOM') and
              ($$ntwo{t} eq 'ROOM')) {
            # Check the diagonal neighbor between those two orthogonals;
            # if it _also_ is room floor, then convert this corridor.
            # Because dirone and dirtwo are adjacent orthogonals, we
            # can just add their dx and dy together to get the diag;
            # and by similar reasoning, we know the diagonal isn't
            # out of bounds, because we checked the orthogonals.
            my $nx = $x + $wdir{$dirone}{dx} + $wdir{$dirtwo}{dx};
            my $ny = $y + $wdir{$dirone}{dy} + $wdir{$dirtwo}{dy};
            if ($map[$nx][$ny]{t} eq 'ROOM') {
              $map[$x][$y] = $floor;
              $anychanges++;
            }
          }
        }
      }
      if ($map[$x][$y]{t} eq 'DOOR') {
        # This check doesn't seem to work as intended.
        #print "DOOR($x,$y): ";
        for my $dirone (keys %wdir) {
          my $dirtwo = $wdir{$dirone}{clockwise};
          my $none = neighbor($x, $y, $dirone);
          my $ntwo = neighbor($x, $y, $dirtwo);
          #print "[$dirone: $$none{t}; $dirtwo: $$none{t}]";
          if ($none and $ntwo and
              ($$none{t} eq 'ROOM') and
              ($$ntwo{t} eq 'ROOM')) {
            #print " => FLOOR ";
            $map[$x][$y] = $floor;
            $anychanges++;
          }
        }
      }
    }
  }
}
for my $x (0 .. $COLNO) {
  for my $y (0 .. $ROWNO) {
    fixwalldirs($x, $y);
  }
}
# Place Stairs:
my ($upstair, $dnstair, $tries);
while ((not $dnstair) and ($tries++ < 4000)) {
  my $x = 2 + int rand ($COLNO - 4);
  my $y = 1 + int rand ($ROWNO - 2);
  if (($map[$x][$y]{t} eq 'ROOM') or
      (($tries > 1000) and ($map[$x][$y]{t} eq 'CORR')) or
      ($tries > 3000)) {
    if ($upstair) {
      $dnstair = [$x, $y];
      $map[$x][$y] = +{ b => 'on_red',
                        t => 'STAIR',
                        c => '>',
                        f => 'bold white',
                      };
    } else {
      $upstair = [$x, $y];
      $map[$x][$y] = +{ b => 'on_red',
                        t => 'STAIR',
                        c => '<',
                        f => 'bold white',
                      };
    }
  }
}
# Other Dungeon Features...
my @randfeature = (+{ name   => 'fountain',
                      tile   => +{ b => 'on_black',
                                   f => 'cyan',
                                   t => 'FOUNTAIN',
                                   c => '{',
                                 },
                      prob   => 55,
                      count  => 3, },
                   +{ name   => 'altar',
                      center => 1,
                      tile   => +{ b => 'on_black',
                                   f => 'yellow',
                                   c => '_',
                                   t => 'ALTAR',
                                },
                      count  => 1,
                      prob   => 15,
                    },
                   +{ name   => 'sink',
                      count  => 1,
                      prob   => 10,
                      onwall => 1,
                      tile   => +{ b => 'on_black',
                                   f => 'cyan',
                                   c => '#',
                                   t => 'SINK',
                                 },
                    },
                   +{ name   => 'monster',
                      count  => 50,
                      prob   => ($domonsters ? 100 : 0),
                      tile   => $floor,
                      monst  => 1,
                    },
                  );
my @monster = ( # This is just for visual flavor.  The actual game
                # will of course generate monsters via its own
                # mechanisms, using difficulty etc.
               +{ name  => 'insect',
                  mlet  => 'a',
                  color => ['yellow', 'blue', 'red', 'green', 'magenta'],
                },
               +{ name  => 'chicken',
                  mlet  => 'c',
                  color => ['yellow', 'red'],
                },
               +{ name  => 'gremlin',
                  mlet  => 'g',
                  color => ['green', 'magenta'],
                },
               +{ name  => 'humanoid',
                  mlet  => 'h',
                  color => ['green', 'red', 'blue', 'magenta'],
                },
               +{ name  => 'nymph',
                  mlet  => 'n',
                  color => ['green', 'blue', 'cyan'],
                },
               +{ name  => 'Centaur',
                  mlet  => 'C',
                  color => ['green', 'cyan'],
                },
               +{ name  => 'Dragon',
                  mlet  => 'D',
                  color => ['black', 'white', 'yellow', 'red', 'blue', 'green'],
                },
               +{ name  => 'Giant',
                  mlet  => 'H',
                  color => ['white', 'cyan', 'yellow', 'blue', 'magenta'],
                },
               +{ name  => 'Troll',
                  mlet  => 'T',
                  color => ['white', 'cyan', 'magenta'],
                },
               +{ name  => 'Vampire',
                  mlet  => 'V',
                  color => ['red', 'blue'],
                },
               +{ name  => 'Human',
                  mlet  => '@',
                  color => ['green', 'green', 'white', 'blue', 'red'],
                },
              );
showmap();

sub showmap {
  print "\nDepth: $depth\n\n";
  for my $y (0 .. $ROWNO) {
    for my $x (0 .. $COLNO) {
      my $m = $map[$x][$y];
      if ($$m{m}) {
        print $reset;
        print color $$m{b};
        print color $$m{m}{f};
        print $$m{m}{c};
      } else {
        print $reset;
        print color $$m{b};
        print color $$m{f};
        print $$m{c};
      }
    }
    print color "reset";
    print "\n";
  }
}

sub randomorder {
  return map {
    $$_[0]
  } sort {
    $$a[1] <=> $$b[1]
  } map {
    [$_ => rand 1776]
  } @_;
}

sub dist {
  my ($xone, $yone, $xtwo, $ytwo, $xscale, $yscale) = @_;
  my $xdist = int(abs($xone - $xtwo) * $xscale / 100);
  my $ydist = int(abs($yone - $ytwo) * $yscale / 100);
  return int sqrt(($xdist * $xdist) + ($ydist * $ydist));
}

sub neighbor {
  my ($x, $y, $wd) = @_;
  my $nx = $x + $wdir{$wd}{dx};
  my $ny = $y + $wdir{$wd}{dy};
  if (($nx < 0) or ($nx > $COLNO) or
      ($ny < 0) or ($ny > $ROWNO)) {
    return;
  }
  #print "[$wd of ($x,$y): ($nx,$ny)] ";
  return $map[$nx][$ny];
}

sub solidneighborcount {
  my ($x, $y, $countsecrets, $countdoors, $countcorridors) = @_;
  my $count = 0;
  for my $nx (($x - 1) .. ($x + 1)) {
    for my $ny (($y - 1) .. ($y + 1)) {
      if (($nx == $x) and ($ny == $y)) {
        # The tile itself is not a neighbor.
      } elsif (($nx < 0) or ($nx > $COLNO) or
               ($ny < 0) or ($ny > $ROWNO) or
               ($map[$nx][$ny]{t} eq 'WALL') or
               ($map[$nx][$ny]{t} eq 'STONE') or
               ($map[$nx][$ny]{f} eq 'blue' and $countsecrets) or
               ($map[$nx][$ny]{t} eq 'DOOR' and $countdoors) or
               ($map[$nx][$ny]{t} eq 'CORR' and $countcorridors)) {
        $count++;
      }
    }
  }
  return $count;
}

sub orthogonalfloorcount {
  my ($x, $y) = @_;
  my $count;
  for my $wd (keys %wdir) {
    my $neighbor = neighbor($x, $y, $wd);
    #my $nx = $x + $wdir{$wd}{dx};
    #my $ny = $y + $wdir{$wd}{dy};
    #if (($nx >= 0) and ($nx <= $COLNO) and
    #    ($ny >= 0) and ($ny <= $ROWNO) and
    #    $map[$nx][$ny]{t} eq 'ROOM') {
    if ($neighbor and $$neighbor{t} eq 'ROOM') {
      $count++;
    }
  }
  return $count;
}

sub fixwalldirs {
  my ($x, $y) = @_;
  if ($map[$x][$y]{t} eq 'WALL') {
    my $wdirs = 0;
    for my $wd (keys %wdir) {
      my $neighbor = neighbor($x, $y, $wd);
      #my $nx = $x + $wdir{$wd}{dx};
      #my $ny = $y + $wdir{$wd}{dy};
      #if (($nx >= 0) and ($nx <= $COLNO) and
      #    ($ny >= 0) and ($ny <= $ROWNO) and
      #    ($map[$nx][$ny]{t} eq 'WALL' or
      #     $map[$nx][$ny]{t} eq 'DOOR')) {
      if ($neighbor and (($$neighbor{t} eq 'WALL') or
                         ($$neighbor{t} eq 'DOOR') or
                         # treat secret corridors as walls here:
                         ($$neighbor{t} eq 'CORR' and $$neighbor{f} eq 'blue'))) {
        $wdirs += $wdir{$wd}{bit};
      }
    }
    $map[$x][$y] = +{ t => 'WALL',
                      c => ($wallglyph[$wdirs] || $map[$x][$y]{c} || '-'),
                      b => 'on_black',
                      f => 'white',
                    };
  }
}
