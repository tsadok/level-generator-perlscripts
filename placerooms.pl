#!/usr/bin/perl -w
# -*- cperl -*-

# Inspired by this article:
# https://www.rockpapershotgun.com/2015/07/28/how-do-roguelikes-generate-levels/

use utf8;
use Term::ANSIColor;
use open ':encoding(UTF-8)';
use open ":std";

my %arg = @ARGV;

my $debug     = $arg{debug} || 0;
my $xmax      = $arg{xmax} || $arg{COLNO} || 79;
my $ymax      = $arg{ymax} || $arg{ROWNO} || 20;
my $unicode   = $arg{unicode} ? "yes" : $arg{ascii} ? undef : "yes";
my $headcolor = $arg{headcolor} || "bold cyan";

my %wdir = ( E => +{ bit => 1, dx =>  1, dy =>  0, clockwise => 'S', },
             N => +{ bit => 2, dx =>  0, dy => -1, clockwise => 'E', },
             W => +{ bit => 4, dx => -1, dy =>  0, clockwise => 'N', },
             S => +{ bit => 8, dx =>  0, dy =>  1, clockwise => 'W', },
           );
my @dir_available = keys %wdir;

my @wallglyph = ($arg{isolatedwallchar}                     || $arg{wallchar} || "-",                    #  0 => does not connect
                 $arg{hwallcharwestend}  || $arg{hwallchar} || $arg{wallchar} || ($unicode ? "─" : "-"), #  1 => connects east
                 $arg{vwallcharsouthend} || $arg{vwallchar} || $arg{wallchar} || ($unicode ? "│" : "|"), #  2 => connects north
                 $arg{swcorner}                             || $arg{wallchar} || ($unicode ? "└" : "-"), #  3 = 1 + 2 => connects east and north
                 $arg{hwallchareastend}  || $arg{hwallchar} || $arg{wallchar} || ($unicode ? "─" : "-"), #  4 => connects west
                 $arg{hwallchar}                            || $arg{wallchar} || ($unicode ? "─" : "-"), #  5 = 1 + 4 => connects east and west
                 $arg{secorner}                             || $arg{wallchar} || ($unicode ? "┘" : "-"), #  6 = 2 + 4 => connects north and west
                 $arg{twallcharnorth}                       || $arg{wallchar} || ($unicode ? "┴" : "-"), #  7 = 1 + 2 + 4 => connects east, north, and west.
                 $arg{vwallcharnorthend} || $arg{vwallchar} || $arg{wallchar} || ($unicode ? "│" : "|"), #  8 => connects south
                 $arg{nwcorner}                             || $arg{wallchar} || ($unicode ? "┌" : "-"), #  9 = 1 + 8 => connects east and south
                 $arg{vwallchar}                            || $arg{wallchar} || ($unicode ? "│" : "|"), # 10 = 2 + 8 => connects north and south
                 $arg{twallcharwest}                        || $arg{wallchar} || ($unicode ? "├" : "|"), # 11 = 1 + 2 + 8 => connects east, north, and south
                 $arg{necorner}                             || $arg{wallchar} || ($unicode ? "┐" : "-"), # 12 = 4 + 8 => connects west and south
                 $arg{twallcharsouth}                       || $arg{wallchar} || ($unicode ? "┬" : "-"), # 13 = 1 + 4 + 8 => connects east, west, and south
                 $arg{twallchareast}                        || $arg{wallchar} || ($unicode ? "┤" : "|"), # 14 = 2 + 4 + 8 => connects north, west, and south
                 $arg{crosswallchar}                        || $arg{wallchar} || ($unicode ? "┼" : "-"), # 15 = 1 + 2 + 4 + 8 => connects all four directions.
                );

my $roomno;
my $level = +{
              title => "First Room",
              map   => generate_room($roomno++),
             };
for (1 .. int(($xmax / 10) * ($ymax / 6))) {
  my $room = generate_room($roomno++);
  my $newlev = add_room_to_level($level, $room);
  if ($newlev) {
    $level = $newlev;
    $$level{title} = "Level After " . $roomno . " Rooms";
    showlevel($level) if $debug =~ /placement/;
  } elsif ($debug =~ /placement/) {
    print "Could not place room $roomno.\n";
  }
}

for my $sdoornum (1 .. 2 + int rand 5) {
  my @c = map {
    $$_[0]
  } sort {
    $$b[1] <=> $$a[1]
  } map {
    [ $_ => distance_around_wall($$level{map}, $$_[0], $$_[1]) + rand 7 ]
  } grep {
    my $c = $_;
    (($$level{map}[$$c[0]][$$c[1]]{type} =~ /WALL|STONE/) and
     (# Could be made a north-to-south door:
      (($$level{map}[$$c[0]][$$c[1]-1]{type} =~ /FLOOR|CORR/) and
       ($$level{map}[$$c[0]][$$c[1]+1]{type} =~ /FLOOR|CORR/)) or
      # Could be made an east-to-west door:
      (($$level{map}[$$c[0]-1][$$c[1]]{type} =~ /FLOOR|CORR/) and
       ($$level{map}[$$c[0]+1][$$c[1]]{type} =~ /FLOOR|CORR/))))
  } map {
    my $x = $_;
    map {
      [$x, $_]
    } 2 .. ($ymax - 1);
  } 2 .. ($xmax - 1);
  my ($x, $y) = @{$c[0]};
  $$level{map}[$x][$y] = terrain("SDOOR");
  if ($debug =~ /placement|secret/) {
    showlevel(+{ title => "Added secret door $sdoornum",
                 map   => $$level{map},
               });
  }
}

$$level{title} = "Finalized Level";
$$level{map}   = fixwalls(undecided_to_stone($$level{map}), checkstone => "yes");
showlevel($level);

exit 0; # Subroutines Follow.

sub distance_walking {
  my ($map, $ox, $oy, $tx, $ty) = @_;
  my $infinity = ($xmax * $ymax) + 1; # Literally: worse than visiting every single tile on the level to get there.
  my $dist = [ map {
    my $x = $_;
    [map {
      $infinity
    } 0 .. $ymax]
  } 0 .. $xmax ];
  $$dist[$ox][$oy] = 0; # Point of origin.
  my $didanything = 1;
  while ($didanything) {
    $didanything = 0;
    for my $x (1 .. $xmax) {
      for my $y (1 .. $ymax) {
        if ($$dist[$x][$y] < $infinity) {
          my $newdist = $$dist[$x][$y] + 1;
          for my $dx (-1 .. 1) {
            for my $dy (-1 .. 1) {
              if (($x + $dx >= 1) and ($x + $dx <= $xmax) and
                  ($y + $dy >= 1) and ($y + $dy <= $ymax) and
                  # it's possible to take that step:
                  ($$map[$x + $dx][$y + $dy]{type} =~ /FLOOR|CORR|DOOR/) and
                  # it's shorter than any previously known path to there:
                  $$dist[$x + $dx][$y + $dy] > $newdist) {
                if (($x + $dx == $tx) and ($y + $dy == $ty)) {
                  return $newdist;
                }
                $$dist[$x + $dx][$y + $dy] = $newdist;
                $didanything++;
              }
            }
          }
        }
      }
    }
  }
  return $infinity;
}

sub distance_around_wall {
  my ($map, $cx, $cy) = @_;
  my ($nsdist, $ewdist) = (0, 0);
  if (($cy > 1) and ($cy < $ymax) and
      ($$map[$cx][$cy - 1]{type} =~ /FLOOR|CORR/) and
      ($$map[$cx][$cy + 1]{type} =~ /FLOOR|CORR/)) {
    $nsdist = distance_walking($map, $cx, $cy - 1, $cx, $cy + 1);
  }
  if (($cx > 1) and ($cx < $xmax) and
      ($$map[$cx - 1][$cy]{type} =~ /FLOOR|CORR/) and
      ($$map[$cx + 1][$cy]{type} =~ /FLOOR|CORR/)) {
    $ewdist = distance_walking($map, $cx - 1, $cy, $cx + 1, $cy);
  }
  return ($nsdist > $ewdist) ? $nsdist : $ewdist;
}

sub can_place_room {
  my ($level, $room, $xoffset, $yoffset) = @_;
  my @wallmatch;
  for my $y (randomorder(1 .. $ymax)) {
    for my $x (randomorder(1 .. $xmax)) {
      if ($$room[$x][$y]{type} ne "UNDECIDED") {
        if (($xoffset + $x < 1) or ($xoffset + $x > $xmax) or
            ($yoffset + $y < 1) or ($yoffset + $y > $ymax)) {
          return 0;
        }
        if ($$room[$x][$y]{type} =~ /DOOR/) {
          # Doors MUST match up:
          if (not $$level{map}[$xoffset + $x][$yoffset + $y]{type} =~ /WALL|DOOR|STONE/) {
            return 0;
          }
        } elsif ($$room[$x][$y]{type} =~ /WALL|STONE/) {
          if ($$level{map}[$xoffset + $x][$yoffset + $y]{type} =~ /WALL|DOOR|STONE/) {
            push @wallmatch, [$x, $y];
          } elsif ($$level{map}[$xoffset + $x][$yoffset + $y]{type} ne "UNDECIDED") {
            return 0;
          }
        } else { # FLOOR or whatever else (water, lava, fountain, altar, etc.) has to go on undecided spots:
          if ($$level{map}[$xoffset + $x][$yoffset + $y]{type} ne "UNDECIDED") {
            return 0;
          }
        }
      }
    }
  }
  return @wallmatch;
}

sub getextrema {
  my ($room) = @_;
  my ($rxmin, $rymin, $rxmax, $rymax) = (undef, undef, undef, undef);
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if ($$room[$x][$y]{type} ne "UNDECIDED") {
        if ((not defined $rxmin) or ($x < $rxmin)) {
          $rxmin = $x;
        }
        if ((not defined $rxmax) or ($x > $rxmax)) {
          $rxmax = $x;
        }
        if ((not defined $rymin) or ($y < $rymin)) {
          $rymin = $y;
        }
        if ((not defined $rymax) or ($y > $rymax)) {
          $rymax = $y;
        }
      }
    }
  }
  print "Extrema: $rxmin, $rymin, $rxmax, $rymax\n" if $debug =~ /extrema/;
  return ($rxmin, $rymin, $rxmax, $rymax);
}

sub add_room_to_level {
  my ($level, $room) = @_;
  my ($possible, $bestx, $besty, $bestcount) = (0, 0, 0, 0);
  my ($rxmin, $rymin, $rxmax, $rymax) = getextrema($room);
  for my $xoffset (randomorder((-1 * $xmax) .. $xmax)) {
    if (($xoffset + $rxmin < 0) or ($xoffset + $rxmax > $xmax)) {
      # Cannot place at this x position (column), no need to test the details.
    } else {
      for my $yoffset (randomorder((-1 * $ymax) .. $ymax)) {
        if (($yoffset + $rymin < 0) or ($yoffset + $rymax > $ymax)) {
          # Cannot place at this (x,y) position, no need to test further details.
        } else {
          my $wallmatchcount = can_place_room($level, $room, $xoffset, $yoffset, $rxmin, $rymin, $rxmax, $rymax);
          if ($wallmatchcount > 0) {
            $possible++;
            if ($wallmatchcount > $bestcount) {
              $bestx = $xoffset;
              $besty = $yoffset;
              $bestcount = $wallmatchcount;
            }
          }
        }
      }
    }
  }
  if ($possible) {
    my ($xoffset, $yoffset) = ($bestx, $besty);
    my $doorcount = 0;
    my @matchpos;
    $$level{map} = fixwalls($$level{map});
    for my $x (1 .. $xmax) {
      for my $y (1 .. $ymax) {
        if (($$room[$x][$y]{type} =~ /WALL|STONE/) and
            ($$level{map}[$xoffset + $x][$yoffset + $y]{type} =~ /DOOR/)) {
          $doorcount++;
        } elsif (($$room[$x][$y]{type} =~ /STONE/) and
                 ($$level{map}[$xoffset + $x][$yoffset + $y]{type} =~ /WALL/)) {
          push @matchpos, [$x, $y];
        } elsif ($$room[$x][$y]{type} ne "UNDECIDED") {
          if ($$room[$x][$y]{type} eq "DOOR") {
            $doorcount++;
          } elsif ($$room[$x][$y]{type} =~ /WALL|STONE/ and
                   $$level{map}[$xoffset + $x][$yoffset + $y]{type} =~ /WALL|STONE/) {
            push @matchpos, [$x, $y];
          }
          $$level{map}[$xoffset + $x][$yoffset + $y] = $$room[$x][$y];
        }
      }
    }
    if (not $doorcount) {
      if (scalar @matchpos) {
        my $coord = $matchpos[rand @matchpos];
        my ($x, $y) = @$coord;
        $$level{map}[$xoffset + $x][$yoffset + $y] = terrain("DOOR");
        # TODO: if there are a lot of possible locations, maybe add a secret door at another one?
      } else {
        print color($arg{errorcolor} || "bold red") . "No place for door!" . color("reset");
        showlevel($level);
        print "Press any key.\n";
        <STDIN>;
      }
    }
    return $level;
  }
  return;
}

sub undecided_to_stone {
  my ($map) = @_;
  return convert_terrain($map, qr/UNDECIDED/, terrain("STONE"), sub { return 1; });
}

sub convert_terrain {
  my ($map, $match, $replacement, $decide) = @_;
  my $count = 0;
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if ($$map[$x][$y]{type} =~ $match) {
        if ($decide->($map, $x, $y, $count++)) {
          $$map[$x][$y] = +{ %$replacement };
        }
      }
    }
  }
  return $map;
}

sub fixwalls {
  my ($map, %arg) = @_;
  # First, check for doors that aren't accessible enough:
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if ($$map[$x][$y]{type} =~ /DOOR|SDOOR/) {
        if (($x > 1) and ($y > 1) and ($x < $xmax) and ($y < $ymax) and
            (# Either it's a vertical door:
             ($$map[$x - 1][$y]{type} =~ /FLOOR|CORR/ and
              $$map[$x + 1][$y]{type} =~ /FLOOR|CORR/ and
              $$map[$x][$y - 1]{type} =~ /WALL|STONE/ and
              $$map[$x][$y + 1]{type} =~ /WALL|STONE/) or
             # Else it's a horizontal door
             ($$map[$x - 1][$y]{type} =~ /WALL|STONE/ and
              $$map[$x + 1][$y]{type} =~ /WALL|STONE/ and
              $$map[$x][$y - 1]{type} =~ /FLOOR|CORR/ and
              $$map[$x][$y + 1]{type} =~ /FLOOR|CORR/))) {
          # This door is okey dokey
        } else {
          if ($$map[$x][$y]{type} eq "SDOOR") {
            # Failed secret door, plaster it over:
            $$map[$x][$y] = terrain("WALL", bg => (($debug =~ /door/) ? "on_blue" : "on_black"));
          } else {
            # Failed regular door, just open it up:
            for my $dx (-1 .. 1) {
              for my $dy (-1 .. 1) {
                if (($x + $dx > 1) and ($x + $dx < $xmax) and
                    ($y + $dy > 1) and ($y + $dy < $ymax) and
                    ((not $dx) or (not $dy) or (50 > rand 100))) {
                  $$map[$x + $dx][$y + $dy] = terrain("FLOOR");
                }}}
          }
        }
      }
    }
  }
  if ($arg{checkstone}) {
    # Check for stone adjacent to floor, make it wall:
    for my $x (1 .. $xmax) {
      for my $y (1 .. $ymax) {
        if ($$map[$x][$y]{type} =~ /STONE/) {
          if (countadjacent($map, $x, $y, qr/FLOOR/)) {
            $$map[$x][$y] = terrain("WALL");
          }
        }
      }
    }
  }

  # ais523 wall direction algorithm.  We start by drawing a square around every
  # open floor space, then remove the parts of the square that do not connect
  # to other walls.
  my %dirbit = ( EAST   => 1,
                 NORTH  => 2,
                 WEST   => 4,
                 SOUTH  => 8,
               );
  my @wmap = map { [map { 0 } 0 .. $ymax ] } 0 .. $xmax;
  for my $x (2 .. ($xmax - 1)) {
    for my $y (2 .. ($ymax - 1)) {
      if ($$map[$x][$y]{type} =~ /FLOOR/) {
        $wmap[$x+1][$y]   |= $dirbit{NORTH} | $dirbit{SOUTH};
        $wmap[$x-1][$y]   |= $dirbit{NORTH} | $dirbit{SOUTH};
        $wmap[$x][$y-1]   |= $dirbit{EAST}  | $dirbit{WEST};
        $wmap[$x][$y+1]   |= $dirbit{EAST}  | $dirbit{WEST};
        $wmap[$x+1][$y+1] |= $dirbit{NORTH} | $dirbit{WEST};
        $wmap[$x-1][$y+1] |= $dirbit{NORTH} | $dirbit{EAST};
        $wmap[$x+1][$y-1] |= $dirbit{SOUTH} | $dirbit{WEST};
        $wmap[$x-1][$y-1] |= $dirbit{SOUTH} | $dirbit{EAST};
      }
    }
  }
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if (($x < $xmax) and not ($$map[$x+1][$y]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{EAST};
      }
      if (($x > 1) and not ($$map[$x-1][$y]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{WEST};
      }
      if (($y < $ymax) and not ($$map[$x][$y+1]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{SOUTH};
      }
      if (($y > 1) and not ($$map[$x][$y-1]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{NORTH};
      }
      if ($$map[$x][$y]{type} eq 'WALL') {
        $$map[$x][$y]{char} = $wallglyph[$wmap[$x][$y]];
      }
    }
  }
  return $map;
}

sub blankmap {
  return [ map {
    [map { terrain("UNDECIDED") } 0 .. $ymax]
  } 0 .. $xmax];
}

sub walls_around_room {
  my ($map) = @_;
  # Convert any undecided tiles that are adjacent to floor into walls.
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if ($$map[$x][$y]{type} eq "UNDECIDED") {
        my $adjfloor = countadjacent($map, $x, $y, qr/FLOOR/);
        if ($adjfloor > 0) {
          $$map[$x][$y] = terrain("WALL");
        }
      }
    }
  }
  return $map;
}

sub generate_room {
  my @arg = @_;
  my @rtype =
    (
     [ 30 => sub { return organic_room(@_);     } ],
     [ 10 => sub { return dead_corridor(@_);    } ],
     [ 50 => sub { return elipseroom(@_);       } ],
     [ 40 => sub { return rectangular_room(@_); } ],
     [ 15 => sub { return vestibule(@_);        } ],
     [ 30 => sub { return multirect_room(@_);   } ],
    );
  my $psum = 0;
  $psum += $$_[0] for @rtype;
  my $type = rand $psum;
  my $sum = 0;
  for my $rt (@rtype) {
    $sum += $$rt[0];
    if ($sum >= $type) {
      return $$rt[1]->(@arg);
    }
  }
  die "Failed to select a room type (wanted $type from $psum, only got to $sum)";
}

sub multirect_room {
  my ($roomno) = @_;
  my $sizex = int(($xmax / 10) + rand($xmax / 4));
  my $sizey = int(($ymax / 5) + rand($ymax / 3));
  my $xoffset = int(($xmax - $sizex) / 2);
  my $yoffset = int(($ymax - $sizey) / 2);
  my $map = blankmap();
  # We overlap several rectangles.
  # 1. a horizontal rectangle guaranteed to use the full x range
  for my $x ($xoffset .. ($xoffset + $sizex)) {
    for my $y (mr_subrange($yoffset, ($yoffset + $sizey))) {
      $$map[$x][$y] = terrain("FLOOR");
    }
  }
  # 2. a vertical rectangle guaranteed to use the full y range
  for my $x (mr_subrange($xoffset, ($xoffset + $sizex))) {
    for my $y ($yoffset .. ($yoffset + $sizey)) {
      $$map[$x][$y] = terrain("FLOOR");
    }
  }
  # 3. zero or more rectangles that use subranges on both axes
  while (25 > int rand 100) {
    for my $x (mr_subrange($xoffset, ($xoffset + $sizex))) {
      for my $y (mr_subrange($yoffset, ($yoffset + $sizey))) {
        $$map[$x][$y] = terrain("FLOOR");
      }
    }
  }
  return walls_around_room($map);
}

sub mr_subrange {
  # helper function for multirect_room
  # returns a subrange guaranteed to cross the middle of the parent range
  my ($min, $max) = @_;
  if ($max - $min < 4) {
    return ($min .. $max);
  }
  my $mid = $min + int((2 * ($max - $min) + 1) / 4);
  my $submin = $min + int rand($mid - $min);
  my $submax = $mid + int rand($max - $mid);
  return ($submin .. $submax);
}

sub elipseroom {
  my ($roomno) = @_;
  my $cx = int($xmax / 2);
  my $cy = int($ymax / 2);
  my $sizex = 5 + int rand(($xmax - 5) / 4);
  my $sizey = 3 + int rand(($ymax - 3) / 3);
  my $radius = int(($sizex - 1) / 2);
  my $aspect = int(1000 * $sizey / $sizex);
  my $yrad   = int($radius * $aspect / 1000);
  #my $fudge  = int rand 500;
  print "Elipse $sizex by $sizey, centered at ($cx,$cy), radii($radius,$yrad), aspect $aspect\n" if $debug =~ /ell?ipse/;
  my $map = blankmap();
  for my $x (($cx - $radius - 1) .. ($cx + $radius + 1)) {
    for my $y (($cy - $yrad - 1) .. ($cy + $yrad + 1)) {
      # Pythagorean Theorem Calculation (with aspect ratio adjustment)
      my $distsquared = (abs($cx - $x) * abs($cx - $x))
        + (int(abs($cy - $y) * $aspect / 500) *
           int(abs($cy - $y) * $aspect / 500));
      if ($distsquared <= ($radius * $radius)) {
        $$map[$x][$y] = terrain("FLOOR");
      }
    }
  }
  return walls_around_room($map);
}

sub vestibule {
  my ($roomno) = @_;
  my $cx = int($xmax / 2);
  my $cy = int($ymax / 2);
  my $map = blankmap();
  for my $x (($cx - 1) .. ($cx + 1)) {
    for my $y (($cy - 1) .. ($cy + 1)) {
      $$map[$x][$y] = terrain("STONE");
    }
  }
  $$map[$cx][$cy] = terrain("CORR");
  my ($dx, $dy) = randomorder(0, (50 > int rand 100) ? 1 : -1);
  $$map[$dx + $dx][$cy + $dy] = terrain("DOOR");
  return $map;
}

sub dead_corridor {
  my ($roomno) = @_;
  my $map = blankmap();
  if (65 > rand(100)) {
    # east/west corridor
    my $y = int($ymax / 2);
    my $length = 2 + int rand($xmax / 2);
    for my $x (1 .. $length) {
      $$map[$x][$y] = terrain("CORR");
      $$map[$x][$y - 1] = terrain("STONE");
      $$map[$x][$y + 1] = terrain("STONE");
    }
    if (80 > int rand 100) {
      # Put a door at one end or the other.
      $$map[(50 > int rand 100) ? 1 : $length][$y] = terrain("DOOR");
    }
  } else {
    # north/south corridor.
    my $x = int($xmax / 2);
    my $length = 2 + int rand($ymax / 2);
    for my $y (1 .. $length) {
      $$map[$x][$y] = terrain("CORR");
      $$map[$x - 1][$y] = terrain("STONE");
      $$map[$x + 1][$y] = terrain("STONE");
    }
    if (80 > int rand 100) {
      # Put a door at one end or the other.
      $$map[$x][(50 > int rand 100) ? 1 : $length] = terrain("DOOR");
    }
  }
  return $map;
}

sub rectangular_room {
  my ($roomno) = @_;
  my $map = blankmap();
  my $xsize = 2 + int rand rand($xmax * 3 / 4 - 4);
  my $ysize = 2 + int rand rand($ymax * 3 / 4 - 4);
  my $xoffset = int(($xmax - $xsize) / 2);
  my $yoffset = int(($ymax - $ysize) / 2);
  for my $x ($xoffset .. ($xoffset + $xsize)) {
    for my $y ($yoffset .. ($yoffset + $ysize)) {
      $$map[$x][$y] = terrain("FLOOR");
    }
  }
  return walls_around_room($map);
}

sub organic_room {
  my ($roomno) = @_;
  my $map = blankmap();
  # Pick xsize and ysize for the room, NOT counting walls.
  my $xsize = 2 + int rand($xmax * 3 / 4 - 4);
  my $ysize = 2 + int rand($ymax * 3 / 4 - 4);
  my $xoffset = int(($xmax - $xsize) / 2);
  my $yoffset = int(($ymax - $ysize) / 2);
  my $maxarea = $xsize * $ysize;
  my $tgtarea = int((($arg{minfloorpct} || 25) + rand(($arg{maxfloorpct} || 80) - ($arg{minfloorpct} || 25))) * $maxarea / 100);
  if ($debug =~ /room/) {
    print "Room specs: $xsize by $ysize, want $tgtarea of $maxarea tiles to be floor.\n";
    print "Press Enter.\n" if $debug =~ /pause/;
    <STDIN> if $debug =~ /pause/;
  }
  my $floortiles = 0;
  my $tries = $maxarea * 100;
  my $cx = int($xsize + 1) / 2;
  my $cy = int($ysize + 1) / 2;
  while (($floortiles < $tgtarea) and ($tries-- > 0)) {
    my $x    = $cx;
    my $y    = $cy;
    my $xdir = (50 > rand 100) ? 1 : -1;
    my $ydir = (50 > rand 100) ? 1 : -1;
    my $dx   = 1 + int(rand($xsize / 10));
    my $dy   = 1 + int(rand($ysize / 10));
    my $frst = (50 > rand 100) ? "x first" : undef;
    my $done = 0;
    while (($x > 0) and ($x < $xsize) and ($y > 0) and ($y < $ysize) and not $done) {
      my $iter = sub {
        if (not $done) {
          if ($$map[$xoffset + $x][$yoffset + $y]{type} eq "UNDECIDED") {
            $$map[$xoffset + $x][$yoffset + $y] = terrain("FLOOR");
            $floortiles++;
            $done = 1;
            if ($debug =~ /room/) {
              showlevel(+{map => $map, title => "Room ($floortiles floor tiles placed)"})
            }
          }}};
      if ($frst) {
        for (1 .. $dx) { $iter->(); $x += $xdir; }
        for (1 .. $dy) { $iter->(); $y += $ydir; }
      } else {
        for (1 .. $dy) { $iter->(); $y += $ydir; }
        for (1 .. $dx) { $iter->(); $x += $xdir; }
      }
    }
  }
  return walls_around_room($map);
}

sub showlevel {
  my ($level) = @_;
  print color($headcolor) . $$level{title} . ":" . color("reset") . "\n";
  if ($arg{showcoords}) {
    print color($arg{coordcolor} || "cyan") . (($ymax >= 100) ? "    " : "   ");
    print join "", map { ($_ % 10) ? " " : int($_ / 10) } 1 .. $xmax;
    print color("reset") . "\n";
    print color($arg{coordcolor} || "cyan") . (($ymax >= 100) ? "    " : "   ");
    print join "", map { $_ % 10 } 1 .. $xmax;
    print color("reset") . "\n";
  }
  for my $y (1 .. $ymax) {
    if ($arg{showcoords}) {
      print color($arg{coordcolor} || "cyan")
        . sprintf((($ymax >= 100) ? "%03d" : "%02d"), $y)
        . color("reset") . " ";
    }
    for my $x (1 .. $xmax) {
      print color "reset";
      my $cell = $$level{map}[$x][$y];
      # TODO: support monsters and items.
      print color $$cell{bg} if $$cell{bg};
      print color $$cell{fg} if $$cell{fg};
      print $$cell{char} || "?";
    }
    print color("reset") . "\n";
  }
}


sub countadjacent {
  my ($map, $x, $y, $typere) = @_;
  my $count = 0;
  for my $cx (($x - 1) .. ($x + 1)) {
    for my $cy (($y - 1) .. ($y + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count.
      } elsif (($cx < 1) or ($cx >= $xmax) or
               ($cy < 1) or ($cy >= $ymax)) {
        # Out of bounds, doesn't count
      } elsif ($$map[$cx][$cy]{type} =~ $typere) {
        $count++;
      }
    }
  }
  return $count;
}

sub randomorder {
  return map {
    $$_[0]
  } sort {
    $$a[1] <=> $$b[1]
  } map {
    [ $_ => rand 1000 ]
  } @_;
}

sub terrain {
  my ($type, %opt) = @_;
  my %ttyp = ( FLOOR => +{ type  => "FLOOR",
                           bg    => "on_black",
                           fg    => "white",
                           char  => ($arg{floorchar} || ($unicode ? '·' : ".")),
                           light => 50,
                         },
               CORR  => +{ type => "CORR",
                           char => "#",
                           bg   => "on_black",
                           fg   => "white", },
               SCORR => +{ type => "CORR",
                           char => "#",
                           bg   => "on_black",
                           fg   => "blue", },
               WALL  => +{ type => "WALL",
                           fg   => "white",
                           bg   => "on_black",
                           char => $arg{wallchar} || "-",
                         },
               DOOR  => +{ type => "DOOR",
                           char => $arg{doorchar} || "+",
                           bg   => "on_black",
                           fg   => "yellow",
                         },
               SDOOR => +{ type => "SDOOR",
                           char => $arg{doorchar} || "+",
                           bg   => "on_black",
                           fg   => "blue",
                         },
               STONE => +{ type => "STONE",
                           char => $arg{stonechar} || ($unicode ? "░" : " "),
                           bg   => "on_black",
                           fg   => "yellow"},
               UNDECIDED => +{ type  => "UNDECIDED",
                               char  => " ",
                               light => 50,
                             },
             );
  if ($ttyp{$type}) {
    my $tile = +{ %{$ttyp{$type}} };
    for my $field (qw(bg fg char)) {
      $$tile{$field} = $opt{$field} if $opt{$field};
    }
    return $tile;
  } else {
    use Carp;
    use Data::Dumper; print Dumper(\%ttyp);
    print color($arg{errorbg} || "on_black") . color($arg{errorfg} || "red") . "Unknown terrain type: '$type'" . color("reset") . "\n";
    carp "Press any key.\n";
    <STDIN>;
  }
}
