#!/usr/bin/perl -w
# -*- cperl -*-

# Inspired by this article:
# https://www.rockpapershotgun.com/2015/07/28/how-do-roguelikes-generate-levels/

use utf8;
use Term::ANSIColor;
use Carp;
use open ':encoding(UTF-8)';
use open ":std";

$|=1;

my %arg = @ARGV;

my $debug     = $arg{debug} || 0;
my $xmax      = $arg{xmax} || $arg{COLNO} || 79;
my $ymax      = $arg{ymax} || $arg{ROWNO} || 20;
my $unicode   = $arg{unicode} ? "yes" : $arg{ascii} ? undef : "yes";
my $headcolor = $arg{headcolor} || "bold cyan";

# Precalculate some ranges, as a minor optimization:
my @rndx      = randomorder(1 .. $xmax);
my @rndy      = randomorder(1 .. $ymax);
my @rndxpos   = randomorder((-1 * $xmax) .. $xmax);
my @rndypos   = randomorder((-1 * $ymax) .. $ymax);

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

my $roomno = 1;
my $level = +{
              title => "First Room",
              map   => ((45 > int rand 100) ? generate_cavern($roomno, $xmax, $ymax) :
                        (85 > int rand 100) ? barbell_room($roomno) : generate_room($roomno)),
             };
showlevel($level) if $debug =~ /placement/;
for (1 .. int(($xmax / 10) * ($ymax / 6))) {
  print ":" if $debug =~ /dots/;
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

for my $sdoornum (1 .. int(($xmax / 8) + rand($xmax / 14))) {
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
  $$level{map}[$x][$y] = terrain((60 > rand 100) ? "SDOOR" : "DOOR");
  if ($debug =~ /placement|secret/) {
    showlevel(+{ title => "Added extra door $sdoornum",
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
  my ($level, $room, $xoffset, $yoffset, $rxmin, $rymin, $rxmax, $rymax) = @_;
  if (($rxmin + $xoffset < 1) or ($rxmax + $xoffset > $xmax) or
      ($rymin + $yoffset < 1) or ($rymax + $yoffset > $ymax)) {
    return 0;
  }
  my @wallmatch;
  for my $y ($rymin .. $rymax) {
    for my $x ($rxmin .. $rxmax) {
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
  my ($rxmin, $rymin, $rxmax, $rymax) = ($xmax, $ymax, 0, 0);
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if ($$room[$x][$y]{type} ne "UNDECIDED") {
        if ($x < $rxmin) {
          $rxmin = $x;
        }
        if ($x > $rxmax) {
          $rxmax = $x;
        }
        if ($y < $rymin) {
          $rymin = $y;
        }
        if ($y > $rymax) {
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
  for my $xoffset (@rndxpos) {
    if (($xoffset + $rxmin < 0) or ($xoffset + $rxmax > $xmax)) {
      # Cannot place at this x position (column), no need to test the details.
    } else {
      for my $yoffset (@rndypos) {
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
        showlevel(+{ title => "(Trying to add this room)", map => $room});
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
        my $floorct = countadjacent($map, $x, $y, qr/FLOOR/);
        if ($floorct < 1) {
          # Doors from one corridor to another should _usually_ be converted to secret corridor.
          if (90 > rand 100) {
            $$map[$x][$y] = terrain("SCORR");
          }
        }
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
                    (not $$map[$x][$y]{type} =~ /FLOOR|CORR/) and
                    ((not $dx) or (not $dy) or (50 > rand 100))) {
                  $$map[$x + $dx][$y + $dy] = terrain("FLOOR");
                }}}
          }
        }
      } elsif ($$map[$x][$y]{type} =~ /CORR/) {
        # While we're at it, clean up any corridors that ended up in rooms:
        my $floorct = countadjacent($map, $x, $y, qr/FLOOR/);
        my $corrct  = countadjacent($map, $x, $y, qr/CORR/);
        if (($floorct > 3) or (($floorct > 1) and not $corrct)) {
          $$map[$x][$y] = terrain("FLOOR");
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
  carp("generate_room(@arg)") if ($debug =~ /carp/);
  print "." if $debug =~ /dots/;
  select undef, undef, undef, $arg{sleep} if $arg{sleep};
  my @rtype =
    (
     [ 30 => sub { return organic_x_room(@_);   } ],
     [ 10 => sub { return dead_corridor(@_);    } ],
     [ 50 => sub { return elipseroom(@_);       } ],
     [ 20 => sub { return rectangular_room(@_); } ],
     [ 15 => sub { return vestibule(@_);        } ],
     [ 30 => sub { return multirect_room(@_);   } ],
     [ 25 => sub { return cavern_room(@_);      } ],
    );
  # This kind only ever fits if done pretty early on:
  push @rtype, [ ((5 - $roomno) * 5) => sub { return barbell_room(@_); } ] if $roomno < 5;
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

sub barbell_room {
  my ($roomno) = @_;
  my ($one, $two, @oneextreme, @twoextreme,
      $oxmin, $oymin, $oxmax, $oymax,
      $txmin, $tymin, $txmax, $tymax);
  my ($xsizesum, $ysizesum) = ($xmax, $ymax); # Guarantee a "re"roll the first time.
  while (($xsizesum > ($xmax / 3)) and ($ysizesum > ($ymax / 2))) {
    $one = generate_room();
    $two = generate_room();
    ($oxmin, $oymin, $oxmax, $oymax) = getextrema($one);
    ($txmin, $tymin, $txmax, $tymax) = getextrema($two);
    $xsizesum = ($oxmax - $oxmin) + ($txmax - $txmin);
    $ysizesum = ($oymax - $oymin) + ($tymax - $tymin);
  }
  # But which way do we want to align the thing, vertically or horizontally?
  my $dovert = 0;
  my $horzweight = $xsizesum * 3000 / $xmax;
  my $vertweight = $ysizesum * 1500 / $ymax;
  if ($horzweight > ($vertweight * 3 / 2)) {
    # Horizontal "costs" more than half again as much as vertical,
    # so let's do vertical:
    $dovert = 1;
  } elsif ($vertweight > ($horzweight * 3 / 2)) {
    $dovert = 0;
  } elsif (rand($horzweight) > rand($vertweight)) {
    $dovert = 1;
  }

  my $map = blankmap();
  if ($dovert) {
    # Room one goes to the north:
    my $offsetone = 1 - $oymin;
    for my $x ($oxmin .. $oxmax) {
      for my $y ($oymin .. $oymax) {
        $$map[$x][$y + $offsetone] = $$one[$x][$y];
      }
    }
    # How long can the corridor be?
    my $maxlen = $ymax - 2 - ($tymax - $tymin) - ($oymax - $oymin);
    # We need a length of at least three, to put doors at both ends.
    if ($maxlen < 3) {
      warn "Vertical barbell max corridor length too small ($maxlen = $ymax - 2 - ($tymax - $tymin) - ($oymax - $oymin))";
      return $one;
    }
    my $corrlen = 3 + int rand($maxlen - 2);
    # But before we draw in the corridor, room two goes to the south:
    my $offsettwo = $oymax + $offsetone + $corrlen - $tymin;
    for my $x ($txmin .. $txmax) {
      for my $y ($tymin .. $tymax) {
        $$map[$x][$y + $offsettwo] = $$two[$x][$y];
      }
    }
    my @spos = grep { $$one[$_][$oymax - 1]{type} =~ /CORR|FLOOR/ } $oxmin .. $oxmax;
    my @epos = grep { $$two[$_][$tymin + 1]{type} =~ /CORR|FLOOR/ } $txmin .. $txmax;
    if (not @spos) {
      warn "Vertical barbell failed to find corridor start position.\n";
      if ($debug =~ /barbell/) {
        showlevel(+{ title => "rooms", map => $map });
        print "Press Enter.\n";
        <STDIN>;
      }}
    if (not @epos) {
      warn "Vertical barbell failed to find corridor end position.\n";
      if ($debug =~ /barbell/) {
        showlevel(+{ title => "rooms", map => $map });
        print "Press Enter.\n";
        <STDIN>;
      }}
    if ((scalar @spos) and (scalar @epos)) {
      my $startx = $spos[rand @spos];
      my $endx   = $epos[rand @epos];
      $$map[$startx][$oymax + $offsetone] = terrain("DOOR");
      $$map[$endx][$tymin + $offsettwo] = terrain("DOOR");
      drawcorridor($map, $startx, $oymax + $offsetone + 1, $endx, $tymin + $offsettwo - 1);
    }
  } else {
    # Do east-to-west barbell.
    # Room one goes to the west:
    my $offsetone = 1 - $oxmin;
    for my $x ($oxmin .. $oxmax) {
      for my $y ($oymin .. $oymax) {
        $$map[$x + $offsetone][$y] = $$one[$x][$y];
      }
    }
    # How long can the corridor be?
    my $maxlen = $xmax - 2 - ($txmax - $txmin) - ($oxmax - $oxmin);
    # We need a length of at least three, to put doors at both ends.
    if ($maxlen < 3) {
      warn "Horizontal barbell max corridor length too small ($maxlen = $xmax - 2 - ($txmax - $txmin) - ($oxmax - $oxmin))";
      return $two;
    }
    my $corrlen = 3 + int rand($maxlen - 2);
    # But before we draw in the corridor, room two goes to the east:
    my $offsettwo = $oxmax + $offsetone + $corrlen - $txmin;
    for my $x ($txmin .. $txmax) {
      for my $y ($tymin .. $tymax) {
        $$map[$x + $offsettwo][$y] = $$two[$x][$y];
      }
    }
    my @spos = grep { $$one[$oxmax - 1][$_]{type} =~ /CORR|FLOOR/ } $oymin .. $oymax;
    my @epos = grep { $$two[$txmin + 1][$_]{type} =~ /CORR|FLOOR/ } $tymin .. $tymax;
    if (not @spos) {
      warn "Horizontal barbell failed to find corridor start position.\n";
      if ($debug =~ /barbell/) {
        showlevel(+{ title => "rooms", map => $map });
        print "Press Enter.\n";
        <STDIN>;
      }}
    if (not @epos) {
      warn "Horizontal barbell failed to find corridor end position.\n";
      if ($debug =~ /barbell/) {
        showlevel(+{ title => "rooms", map => $map });
        print "Press Enter.\n";
        <STDIN>;
      }}
    if ((scalar @spos) and (scalar @epos)) {
      my $starty = $spos[rand @spos];
      my $endy   = $epos[rand @epos];
      $$map[$oxmax + $offsetone][$starty] = terrain("DOOR");
      $$map[$txmin + $offsettwo][$endy] = terrain("DOOR");
      drawcorridor($map, $oxmax + $offsetone + 1, $starty, $txmin + $offsettwo - 1, $endy);
    }
  }
  return $map;
}

sub drawcorridor {
  my ($map, $ox, $oy, $tx, $ty, $terrain) = @_;
  my $xdir = ($tx <=> $ox);
  my $ydir = ($ty <=> $oy);
  $$map[$ox][$oy] = terrain($terrain || "CORR");
  my $dx = abs($tx - $ox);
  my $dy = abs($ty - $oy);
  if ($dx or $dy) {
    my $pick = rand($dx + $dy);
    if ($pick > $dx) {
      drawcorridor($map, $ox, $oy + $ydir, $tx, $ty, $terrain);
    } else {
      drawcorridor($map, $ox + $xdir, $oy, $tx, $ty, $terrain);
    }
  }
}

sub cavern_room {
  my ($roomno) = @_;
  my $sizex = int($xmax / (2 + int rand 3));
  my $sizey = int($ymax * 2 / (3 + int rand 3));
  return generate_cavern($roomno, $sizex, $sizey);
}

sub generate_cavern {
  my ($roomno, $sizex, $sizey) = @_;
  # Initialize map to 55% floor, 45% wall, at random:
  my $map = [map {
    my $x = $_;
    [map {
      my $y = $_;
      terrain((($x == 1) or ($x >= $sizex) or
               ($y == 1) or ($y >= $sizey)) ? "UNDECIDED":
              (55 > rand 100) ? "FLOOR" : "WALL");
    } 0 .. $ymax]
  } 0 .. $xmax];
  # Apply usually 5 (sometimes 4 or 6, occasionally 3 or 7), rounds of smoothing:
  for my $pass (1 .. ((55 > int rand 100) ? 5 : (75 > int rand 100) ? (4 + int rand 3) : (3 + int rand 5))) {
    if ($debug =~ /cavern|smooth/) {
      showlevel(+{ title => "Cavern (About to be Smoothed, Pass $pass)", map => $map });
    }
    for my $y (randomorder(2 .. ($sizey - 1))) {
      for my $x (randomorder(2 .. ($sizex - 1))) {
        if ($$map[$x][$y]{type} eq "FLOOR") {
          if (countadjacent($map, $x, $y, qr/FLOOR/) < 4) {
            $$map[$x][$y] = terrain("WALL");
          }
        } elsif ($$map[$x][$y]{type} eq "WALL") {
          if (countadjacent($map, $x, $y, qr/FLOOR/) >= 6) {
            $$map[$x][$y] = terrain("FLOOR");
          }
        }
      }
    }
  }
  if ($debug =~ /cavern/) {
    showlevel(+{ title => "Cavern (Preselection)", map => $map });
  }
  my $mask = blankmap();
  my @candidate = ();
  for my $x (randomorder(2 .. $sizex)) {
    for my $y (randomorder(2 .. $sizey)) {
      if (($$map[$x][$y]{type} =~ /FLOOR/) and
          ($$mask[$x][$y]{type} eq "UNDECIDED")) {
        push @candidate, [$x, $y, cavern_paint_mask($map, $mask, $x, $y)];
      }
    }
  }
  @candidate = sort { $$b[2] <=> $$a[2] } @candidate;
  if (not @candidate) {
    warn "No candidates for cavern ($sizex, $sizey).  Punting...\n" if $debug;
    if ($debug =~ /cavern/) {
      print "Press Enter...\n";
      <STDIN>;
    }
    return generate_room($roomno);
  }
  if ($debug =~ /cavern/) {
    print "Cavern candidate(s):\n"
      . (join "", map { sprintf("  (%02d,%02d):  %3d\n", @$_) } @candidate);
  }
  my $cavern = blankmap();
  my ($x, $y, $size) = @{$candidate[0]};
  print "Selected cavern has $size floor tiles.\n" if $debug =~ /cavern/;
  cavern_paint_mask($map, $cavern, $x, $y);
  $cavern = walls_around_room($cavern);
  showlevel(+{ title => "Cavern (Finalized)", map => $cavern }) if $debug =~ /cavern/;
  return $cavern;
}

sub cavern_paint_mask {
  my ($map, $mask, $x, $y) = @_;
  my $count = 0;
  no warnings 'recursion';
  if (($$map[$x][$y]{type} =~ /FLOOR/) and
      ($$mask[$x][$y]{type} eq "UNDECIDED")) {
    $$mask[$x][$y] = terrain("FLOOR");
    $count++;
    if ($x > 2) {
      $count += cavern_paint_mask($map, $mask, $x - 1, $y);
    }
    if ($x + 1 < $xmax) {
      $count += cavern_paint_mask($map, $mask, $x + 1, $y);
    }
    if ($y > 2) {
      $count += cavern_paint_mask($map, $mask, $x, $y - 1);
    }
    if ($y + 1 < $ymax) {
      $count += cavern_paint_mask($map, $mask, $x, $y + 1);
    }
  }
  return $count;
}

sub multirect_room {
  my ($roomno) = @_;
  my $sizex = int(($xmax / 10) + rand rand($xmax / 3));
  my $sizey = int(($ymax / 5) + rand rand($ymax / 2));
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
  if (60 > int rand 100) {
    $map = smoothe_map($map);
  }
  return walls_around_room($map);
}

sub smoothe_map {
  my ($map) = @_;
  for my $x (@rndx) {
    for my $y (@rndy) {
      if ($$map[$x][$y]{type} =~ /UNDECIDED/) {
        if (countadjacent($map, $x, $y, qr/FLOOR/) >= 3 + int rand 3) {
          $$map[$x][$y] = terrain("FLOOR");
        }
      }
    }
  }
  return $map;
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
  $$map[$cx + $dx][$cy + $dy] = terrain((35 > rand 100) ? "SDOOR" : "DOOR");
  showlevel(+{ title => "vestibule", map => $map }) if $debug =~ /vestibule/;
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
  my $xsize = 2 + int rand rand($xmax * 2 / 3 - 4);
  my $ysize = 2 + int rand rand($ymax * 2 / 3 - 4);
  my $xoffset = int(($xmax - $xsize) / 2);
  my $yoffset = int(($ymax - $ysize) / 2);
  for my $x ($xoffset .. ($xoffset + $xsize)) {
    for my $y ($yoffset .. ($yoffset + $ysize)) {
      $$map[$x][$y] = terrain("FLOOR");
    }
  }
  return walls_around_room($map);
}

sub organic_x_room {
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
  if (65 > int rand 100) {
    $map = smoothe_map($map);
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
    carp "Press Enter...\n";
    <STDIN>;
  }
}
