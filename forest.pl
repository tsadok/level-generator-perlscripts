#!/usr/bin/perl

use utf8;
use open ':encoding(UTF-8)';
use open ":std";

my $debug        = 0;
my $usecolor     = 1;
my $COLNO        = 79;#90;#79;
my $ROWNO        = 20;#35;#20;
my $floorchar    = '·';

use strict;
use Term::ANSIColor;

my %wdir = ( E => +{ bit => 1, dx =>  1, dy =>  0, clockwise => 'S', },
             N => +{ bit => 2, dx =>  0, dy => -1, clockwise => 'E', },
             W => +{ bit => 4, dx => -1, dy =>  0, clockwise => 'N', },
             S => +{ bit => 8, dx =>  0, dy =>  1, clockwise => 'W', },
           );
my @dir_available = keys %wdir;
my @wallglyph = qw/! ─ │ └ ─ ─ ┘ ┴ │ ┌ │ ├ ┐ ┬ ┤ ┼/;
$wallglyph[0] = '-';
my @neighbormatrix = ([-1, -1], [0, -1], [1, -1],
                      [-1, 0],           [1, 0],
                      [-1, 1],  [0, 1],  [1, 1]);

my $map = generate();

showmap($map);
appendhtml($map);
exit 0; # subroutines follow

sub generate {
  my $map = [ map { [ map {
    +{ type => 'UNDECIDED',
       bg   => 'on_black',
       fg   => 'yellow',
       char => '?',
     };
  } 0 .. $ROWNO ] } 0 .. $COLNO];

  my @pos = map {
    my $x = $_;
    map {
      my $y = $_;
      [$x, $y];
    } 0 .. $ROWNO;
  } 0 .. $COLNO;
  for my $pi (0 .. ((scalar @pos) - 1)) {
    my $opi = int rand @pos;
    ($pos[$pi], $pos[$opi]) = ($pos[$opi], $pos[$pi]);
  }
  for my $pi (0 .. ((scalar @pos) - 1)) {
    my ($x, $y) = @{$pos[$pi]};
    my $thresshold = (70 > int rand 100) ? 5 : 6;
    my $u = countadjacent($map, $x, $y, 'UNDECIDED');
    if ($u == 8) {
      $$map[$x][$y] = +{ type => 'ROOM',
                         char => ($debug ? $u : $floorchar),
                         fg   => 'white',
                         bg   => 'on_black',
                       };
    } elsif ($u >= $thresshold) {
      $$map[$x][$y] = +{ type => 'TREE',
                         char => '#',
                         fg   => 'green',
                         bg   => 'on_black',
                       };
    } else {
      $$map[$x][$y] = +{ type => 'ROOM',
                         char => ($debug ? $u : $floorchar),
                         fg   => ($debug ? 'red' : 'white'),
                         bg   => 'on_black',
                       };
    }
    showmap($map) if (($debug > 3) and (not $pi % 20));
  }

  # Now let's place a few denser clusters of trees
  # interspersed with clearings.
  my $minx = -2;
  while ($minx < ($COLNO - 5)) {
    my $maxx = $minx + 6 + int rand 3;
    if ($maxx + 3 >= $COLNO) {
      $maxx = $COLNO + 3;
    }
    my $miny = -2;
    while ($miny + 3 < $ROWNO) {
      my $maxy = $miny + ($maxx - $minx) - 1;
      if (50 > int rand 100) {
        $maxy--;
      }
      if ($maxy + 2 >= $ROWNO) {
        $maxy = $ROWNO + 2;
      }
      my $cx = int(($minx + $maxx) / 2);
      my $cy = int(($miny + $maxy) / 2);
      my $radius = int(($maxx - $minx) / 2);
      if ($radius > (3 + int rand 5)) {
        $radius--;
      }
      if ($radius * 2 > ($maxy - $miny)) {
        $radius = int(($maxy - $miny) / 2);
      }
      if (33 > int rand 100) {
        $cx = $minx + $radius;
      } elsif (50 > int rand 100) {
        $cx = $maxx - $radius;
      }
      if (33 > int rand 100) {
        $cy = $maxy - $radius;
      } elsif (50 > int rand 100) {
        $cy = $miny + $radius;
      }
      if ((($minx < 3 or $maxx > $COLNO - 3 or $miny < 2 or $maxy > $ROWNO - 2) ? 85 : 60)
          > int rand 100) {
        placeblob($map, $cx, $cy, $radius, +{ type => 'TREE',
                                              char => '#',
                                              fg   => ($debug ? 'red' : 'green'),
                                              bg   => 'on_black', });
      } elsif (65 > int rand 100) {
        placeblob($map, $cx, $cy, $radius, +{ type => 'ROOM',
                                              char => $floorchar,
                                              fg   => ($debug ? 'red' : 'white'),
                                              bg   => 'on_black', });
      }

      $miny = $maxy + 1;
    }
    $minx = $maxx + 1;
  }

  # Surrouned the outer edge with unchoppable trees.
  for my $x (0 .. $COLNO) {
    $$map[$x][0] = +{ type => 'TREE',
                      char => '#',
                      fg   => 'green',
                      bg   => 'on_black',  };
    $$map[$x][$ROWNO] = +{ type => 'TREE',
                           char => '#',
                           fg   => 'green',
                           bg   => 'on_black',  };
  }
  for my $y (0 .. $ROWNO) {
    $$map[0][$y] = +{ type => 'TREE',
                      char => '#',
                      fg   => 'green',
                      bg   => 'on_black',  };
    $$map[$COLNO][$y] = +{ type => 'TREE',
                           char => '#',
                           fg   => 'green',
                           bg   => 'on_black',  };
  }

  # Now let's see about some water maybe...
  if (25 > int rand 100) {
    # pools of water
    my $pcount = 3 + int rand 6;
    print "$pcount Pools\n" if $debug;
    for (1 .. $pcount) {
      placeblob($map,
                int rand $COLNO,
                int rand $ROWNO,
                2 + int rand 5,
                +{ type => 'POOL',
                   char => '}',
                   fg   => 'blue',
                   bg   => 'on_black',
                 }, 1);
    }
  } elsif (33 > int rand 100) {
    # edge-to-edge river
    my $edgeone = $dir_available[rand @dir_available];
    my $edgetwo = $wdir{$edgeone}{clockwise};
    if (70 > int rand 100) {
      # usually go clear across
      $edgetwo = $wdir{$edgetwo}{clockwise};
    }
    my ($xone, $yone) = spotonedge($edgeone, 5, 2);
    my ($xtwo, $ytwo) = spotonedge($edgetwo, 5, 2);
    print "River from $edgeone ($xone, $yone) to $edgetwo ($xtwo, $ytwo)\n" if $debug;
    makeriver($map, $xone, $yone, $xtwo, $ytwo,
              +{ type => 'POOL', char => '}', fg => 'blue', bg => 'on_black', });
  } elsif (50 > int rand 100) {
    # Single lake with a river to the edge.
    print "Lake and river.\n" if $debug;
    my $radius = 5 + int rand int($ROWNO / 3);
    my $lakex  = 5 + $radius + int rand($COLNO - 2 * $radius - 10);
    my $lakey  = 2 + $radius + int rand($ROWNO - 2 * $radius - 4);
    my $redge  = $dir_available[rand @dir_available];
    my ($edgex, $edgey) = spotonedge($redge, 5, 2);
    print "Lake at ($lakex, $lakey) radius $radius; river to $redge ($edgex, $edgey)\n" if $debug > 1;
    makeriver($map, $lakex, $lakey, $edgex, $edgey,
              +{ type => 'POOL', char => '}', fg => 'blue', bg => 'on_black', });
    placeblob($map, $lakex, $lakey, $radius,
              +{ type => 'POOL', char => '}', fg => 'blue', bg => 'on_black', }, 1);
  }

  # Place the up stairs...
  my ($x, $y) = (-1, -1);
  my $tries = 0;
  while ((($x < 2) or ($y < 1) or ($x + 4 >= $COLNO) or ($y + 2 >= $ROWNO) or
          ($$map[$x][$y]{type} ne 'ROOM') or (countadjacent($map, $x, $y, 'ROOM') < 2))
         and $tries < 100) {
    $tries++;
    $x = 2 + int rand (($COLNO + $tries) / 5);
    $y = 2 + int rand ($ROWNO - 4);
  }
  placeblob($map, $x, $y, 2, +{ type => 'ROOM',
                                char => $floorchar,
                                bg   => 'on_black',
                                fg   => 'white', }, 1);
  $$map[$x][$y] = +{ type => 'STAIR',
                    char => '<',
                    bg   => 'on_red',
                    fg   => 'white',
                   };
  # And the down stairs...
  ($x, $y) = (-1, -1);
  $tries = 0;
  while ((($x < 2) or ($y < 1) or ($x + 4 >= $COLNO) or ($y + 2 >= $ROWNO) or
          ($$map[$x][$y]{type} ne 'ROOM') or (countadjacent($map, $x, $y, 'ROOM') < 2))
         and $tries < 100) {
    $tries++;
    $x = $COLNO - 2 - int rand (($COLNO + $tries) / 5);
    $y = $ROWNO - 2 - int rand ($ROWNO - 4);
  }
  placeblob($map, $x, $y, 2, +{ type => 'ROOM',
                                char => $floorchar,
                                bg   => 'on_black',
                                fg   => 'white', }, 1);
  $$map[$x][$y] = +{ type => 'STAIR',
                    char => '>',
                    bg   => 'on_red',
                    fg   => 'white',
                  };

  return $map;
}

sub makeriver {
  my ($map, $x, $y, $tx, $ty, $liquid) = @_;
  my $tries = 0;
  my $twisty = 5 + int rand 20;
  my $minwidth = (50 > int rand 100) ? 2 : 1;
  my $maxwidth = $minwidth + (50 > int rand 100) ? 2 : 1;
  my $avgwidth = int(($minwidth + $maxwidth) / 2);
  my $width = $minwidth + int rand($maxwidth - $minwidth);
  print "Width $minwidth - $maxwidth, avg $avgwidth; twisty $twisty\n" if $debug > 1;
  while ((($x ne $tx) or ($y ne $ty)) and ($tries++ < (2 * ($COLNO + $ROWNO)))) {
    my $progress = ((100 - $twisty) > int rand 100) ? 1 : -1;
    my $xneed = 3 + abs($tx - $x);
    my $yneed = 3 + abs($ty - $y);
    if (50 > int rand 100) {
      $width += (50 > int rand 100) ? -1 : 1;
      if ($width > $maxwidth) {
        $width--;
      } elsif ($width < $minwidth) {
        $width++;
      }
    }
    print "($x,$y), n($xneed,$yneed) " if $debug > 3;
    if ((100 * $xneed / ($xneed + $yneed)) > int rand 100) {
      print "x $progress " if $debug > 5;
      $x += $progress * (($tx > $x) ? 1 : -1);
    } else {
      print "y $progress " if $debug > 5;
      $y += $progress * (($ty > $y) ? 1 : -1);
    }
    placeblob($map, $x, $y, (int(($width * 2 + 1) / 4) + 1), $liquid);
  }
  print " $tries\n" if $debug > 2;
}

sub placeblob {
  my ($map, $cx, $cy, $radius, $terrain, $margin) = @_;
  for my $x (($cx - $radius) .. ($cx + $radius)) {
    for my $y (($cy - int($radius * 2 / 3)) .. ($cy + int($radius * 2 / 3))) {
      my $dist = int sqrt((($cx - $x) * ($cx - $x)) + (($cy - $y) * ($cy - $y)));
      if (($x >= 0 + $margin) and ($x <= $COLNO - $margin) and
          ($y >= 0 + $margin) and ($y <= $ROWNO - $margin) and
          ((int rand $dist) < (int rand $radius))) {
        $$map[$x][$y] = { %$terrain };
      }
    }
  }
}

sub countadjacent {
  my ($map, $x, $y, $type, $char) = @_;
  my $count = 0;
  for my $cx (($x - 1) .. ($x + 1)) {
    for my $cy (($y - 1) .. ($y + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count.
      } elsif (($cx < 0) or ($cx > $COLNO) or
               ($cy < 0) or ($cy > $ROWNO)) {
        # Out of bounds, doesn't count
      } elsif ($$map[$cx][$cy]{type} eq $type) {
        #if ((not $char) or ($char eq $$map[$cx][$cy]{char})) {
          $count++;
        #}
      }
    }
  }
  return $count;
}

sub countortho {
  my ($map, $x, $y, $type) = @_;
  my $count = 0;
  for my $dx (-1 .. 1) {
    for my $dy (-1 .. 1) {
      if ((abs($dx) xor abs($dy)) and
          ($$map[$x + $dx][$y + $dy]{type} eq $type)) {
        $count++;
      }
    }
  }
  return $count;
}

sub spotonedge {
  my ($wd, $margin, $ymargin) = @_;
  # The wdir is which direction you have to move to hit (usually, to
  # hit an adjacent wall immediately, but in our case, to hit the edge
  # in question if you keep going), realized mainly in the dx and dy
  # values.  To pick a spot _on_ that edge, we want to pick a random
  # coordinate for the dimension with a delta of 0, so that we can be
  # anywhere along the edge.  For a delta of -1 we want 0, or for a
  # delta of +1 we want $COLNO or $ROWNO as the case may be. There's
  # probably some convoluted arithmetic formula I could use to work
  # this all out in a single expression, but for simplicity and
  # easy code maintainability I'm going to go with if/elsif/else.
  my ($ex, $ey);
  $ymargin ||= $margin;
  if ($wdir{$wd}{dx} > 0) { # East edge
    $ex = $COLNO;
  } elsif ($wdir{$wd}{dx} < 0) { # West edge
    $ex = 0;
  } else {
    $ex = $margin + int rand($COLNO - 2 * $margin);
  }
  if ($wdir{$wd}{dy} > 0) { # South edge
    $ey = $ROWNO
  } elsif ($wdir{$wd}{dy} < 0) { # North edge
    $ey = 0;
  } else {
    $ey = $ymargin + int rand($ROWNO - 2 * $ymargin);
  }
  return ($ex, $ey);
}

sub fixupwalls {
  my ($map) = @_;
  for my $x (0 .. ($COLNO)) {
    for my $y (0 .. ($ROWNO)) {
      my $fg = $$map[$x][$y]{fg} || 'yellow';
      if ($$map[$x][$y]{type} =~ /STONE|WALL|UNDECIDED/) {
        if (countadjacent($map, $x, $y, qr/ROOM/)) {
          $$map[$x][$y] = +{ type => 'WALL',
                             char => '-',
                             bg   => 'on_black',
                             fg   => $fg,
                           };
        } else {
          $$map[$x][$y] = +{ type => 'STONE',
                             char => ' ',
                             bg   => 'on_black',
                             fg   => $fg,
                           };
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
  my @wmap = map { [map { 0 } 0 .. $ROWNO ] } 0 .. $COLNO;
  for my $x (1 .. ($COLNO - 1)) {
    for my $y (1 .. ($ROWNO - 1)) {
      if ($$map[$x][$y]{type} eq 'ROOM') {
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
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      if (($x < $COLNO) and not ($$map[$x+1][$y]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{EAST};
      }
      if (($x > 0) and not ($$map[$x-1][$y]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{WEST};
      }
      if (($y < $ROWNO) and not ($$map[$x][$y+1]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{SOUTH};
      }
      if (($y > 0) and not ($$map[$x][$y-1]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{NORTH};
      }
      if ($$map[$x][$y]{type} eq 'WALL') {
        $$map[$x][$y]{char} = $wallglyph[$wmap[$x][$y]];
      }
    }
  }
}

sub appendhtml {
  my ($map) = @_;
  use HTML::Entities;
  open HTML, ">>", "forest-levels.xml";
  print HTML qq[<div class="leveltitle">Forest Level:</div>
<table class="level mineslevel"><thead>
   <tr>] . (join "", map { qq[<th class="numeric">$_</th>] } 0 .. $COLNO) . qq[</tr>
</thead><tbody>
   ] . (join "\n   ", map {
     my $y = $_;
     qq[<tr><th class="numeric">$y</th>] . ( join "", map {
       my $x = $_;
       my $char = ($$map[$x][$y]{char} =~ /["<>']/) ? encode_entities($$map[$x][$y]{char}) : $$map[$x][$y]{char};
       qq[<td class="nhtile $$map[$x][$y]{type}tile">$char</td>]
     } 0 .. $COLNO) . qq[</tr>]
   } 0 .. $ROWNO) . qq[</tbody></table>\n<hr />\n];
  close HTML;
}

sub showmap {
  my ($map) = @_;
  #print cls();
  print "\n\n   ";
  for my $cx (0 .. $COLNO) {
    if (not ($cx % 10)) {
      print int ($cx / 10);
    } else {
      print " ";
    }
  }
  print "\n   ";
  for my $cx (0 .. $COLNO) {
    print int ($cx % 10);
  }
  print "\n";
  for my $cy (0 .. $ROWNO) {
    print sprintf "%02d ", $cy;
    for my $cx (0 .. $COLNO) {
      print color "$$map[$cx][$cy]{fg} $$map[$cx][$cy]{bg}" if $usecolor;
      print $$map[$cx][$cy]{char};
    }
    print color "reset" if $usecolor;
    print "\n";
  }
  print "\n\n";
  if ($debug > 7) {
    <STDIN>;
  }
}
