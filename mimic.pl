#!/usr/bin/perl

my $debug        = 0;
my $usecolor     = 1;
my $numofclosets = 7;
my $minbuffer    = 2;
my $minaccess    = 4; # minbuffer + minaccess MUST be strictly less, preferably significantly less, than COLNO or ROWNO.
my $COLNO        = 79;
my $ROWNO        = 20;
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

my $map = generate();
showmap($map);
appendhtml($map);
exit 0; # subroutines follow

sub generate {
  my @closet = map { undef } 1 .. $numofclosets;
  my ($stairx, $stairy);
  my @map = map { [ map {
    +{  type => 'UNDECIDED', char => ' ', bg => 'on_black', };
  } 0 .. $ROWNO ] } 0 .. $COLNO;
  for my $x (0 .. $COLNO) {
    $map[$x][0]          = +{ type => 'STONE', char => ' ', bg => 'on_black', fg => 'yellow', };
    $map[$x][1]          = +{ type => 'WALL',  char => '0', bg => 'on_black', fg => 'yellow', };
    $map[$x][$ROWNO]     = +{ type => 'STONE', char => ' ', bg => 'on_black', fg => 'yellow', };
    $map[$x][$ROWNO - 1] = +{ type => 'WALL',  char => '0', bg => 'on_black', fg => 'yellow', };
  }
  for my $y (1 .. ($ROWNO - 1)) {
    $map[0][$y]          = +{ type => 'STONE', char => ' ', bg => 'on_black', fg => 'yellow', };
    $map[1][$y]          = +{ type => 'WALL',  char => '0', bg => 'on_black', fg => 'yellow', };
    $map[$COLNO][$y]     = +{ type => 'STONE', char => ' ', bg => 'on_black', fg => 'yellow', };
    $map[$COLNO - 1][$y] = +{ type => 'WALL',  char => '0', bg => 'on_black', fg => 'yellow', };
  }
  for my $cnum (0 .. ($numofclosets - 1)) {
    my $tries = 0;
    while (not defined $closet[$cnum]) {
      my $cx = $minbuffer + 1 + int rand($COLNO - ($minbuffer * 2) - 2);
      my $cy = $minbuffer + 1 + int rand($ROWNO - ($minbuffer * 2) - 2);
      my ($cd, $ax, $ay);
      if ($tries++ > 1000) {
        warn "Ran past 1000 tries picking closet locations.  Starting over.";
        return generate();
      }
      do {
        $cd = $dir_available[int rand @dir_available];
        $ax = $cx + ($minaccess + 2) * $wdir{$cd}{dx};
        $ay = $cy + ($minaccess + 2) * $wdir{$cd}{dy};
      } while (($ax <= 1) or ($ax >= ($COLNO - 1)) or
               ($ay <= 1) or ($ay >= ($ROWNO - 1)));
      # Make sure it's not "too close" to any of the other closets...
      my $conflict = 0;
      for my $idx (0 .. ($cnum - 1)) {
        my $rectone = closet_rectangle($closet[$idx]{cx}, $closet[$idx]{cy},
                                       $closet[$idx]{dx}, $closet[$idx]{dy},
                                       $idx, undef, undef, undef);
        my $recttwo = closet_rectangle($cx, $cy,
                                       $wdir{$cd}{dx}, $wdir{$cd}{dy},
                                       $cnum, undef, undef, undef);
        if (rectangles_overlap($rectone, $recttwo)) {
          $conflict++;
        }
      }
      if (not $conflict) {
        $closet[$cnum] = +{ num => $cnum,
                            cx  => $cx,
                            cy  => $cy,
                            dx  => $wdir{$cd}{dx},
                            dy  => $wdir{$cd}{dy},
                          };
      }}}
  # Ok, so we know where the closets go.  Place them on the map:
  for my $cnum (0 .. ($numofclosets - 1)) {
    closet_rectangle($closet[$cnum]{cx}, $closet[$cnum]{cy},
                     $closet[$cnum]{dx}, $closet[$cnum]{dy},
                     $cnum, 'doplace', \@map, ($cnum > 0 ? 1 : 0));
    showmap(\@map) if $debug > 4;
  }
  $stairx = $closet[$numofclosets - 1]{cx} + ($closet[$numofclosets - 1]{dx} * $minaccess);
  $stairy = $closet[$numofclosets - 1]{cy} + ($closet[$numofclosets - 1]{dy} * $minaccess);
  # We now want to grow the caverns until the various areas connect.
  # While doing so, we want to visit floor positions in a shuffled order.
  my $numofpositions = 0;
  my @posn;
  for my $x (2 .. ($COLNO - 2)) {
    for my $y (2 .. ($ROWNO - 2)) {
      $posn[$numofpositions] = +{ x => $x, y => $y, };
      $numofpositions++;
    }
  }
  for my $pone (0 .. ($numofpositions - 1)) {
    my $ptwo = int rand $numofpositions;
    my ($shuffx, $shuffy) = ($posn[$pone]{x}, $posn[$pone]{y});
    ($posn[$pone]{x}, $posn[$pone]{y}) = ($posn[$ptwo]{x}, $posn[$ptwo]{y});
    ($posn[$ptwo]{x}, $posn[$ptwo]{y}) = ($shuffx, $shuffy);
  }
  my $areas = countareas(\@map, qr/ROOM|DOOR/);
  my $tries = 0;
  while ($areas > 1) {
    if ($tries++ > (4 * $ROWNO * $COLNO)) {
      warn "Spent too long attempting to connect areas.  Restarting...\n" if $debug;
      return generate();
    } elsif (not undecided_spots_exist(\@map)) {
      warn "Ran out of undecided areas.  Restarting...\n" if $debug;
      return generate();
    }
    for my $p (0 .. ($numofpositions - 1)) {
      my ($x, $y) = ($posn[$p]{x}, $posn[$p]{y});
      if ($map[$x][$y]{type} eq 'UNDECIDED') {
        if (countortho(\@map, $x, $y, 'ROOM') > int rand 10) {
          $map[$x][$y] = +{ type => 'ROOM',
                            char => $floorchar,
                            fg   => 'yellow',
                            bg   => 'on_black',
                          };
          ($stairx, $stairy) = ($x, $y);
        } elsif ((countortho(\@map, $x, $y, 'WALL')  > int rand 25) or
                 (countortho(\@map, $x, $y, 'STONE') > int rand 12)) {
          $map[$x][$y] = +{ type => 'WALL',
                            char => 'X',
                            fg   => 'yellow',
                            bg   => 'on_black',
                          };
        }
      }
    }
    $areas = countareas(\@map, qr/ROOM|DOOR/);
    if ($debug > 3) {
      showmap(\@map);
      print "Distinct Floor Areas: $areas\n";
    }
  }
  # Fix up stone versus wall.
  for my $x (0 .. ($COLNO)) {
    for my $y (0 .. ($ROWNO)) {
      if ($map[$x][$y]{type} =~ /STONE|WALL|UNDECIDED/) {
        if (countadjacent(\@map, $x, $y, 'ROOM')) {
          $map[$x][$y] = +{ type => 'WALL',
                            char => '-',
                            bg   => 'on_black',
                            fg   => 'yellow',
                          };
        } else {
          $map[$x][$y] = +{ type => 'STONE',
                            char => ' ',
                            bg   => 'on_black',
                            fg   => 'yellow',
                          };
        }
      }
    }
  }
  # Now fix the wall directions...
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      if ($map[$x][$y]{type} eq 'WALL') {
        my $wdirs = 0;
        for my $wd (keys %wdir) {
          my $neighbor = undef;
          my $nx = $x + $wdir{$wd}{dx};
          my $ny = $y + $wdir{$wd}{dy};
          if (($nx >= 0) and ($nx <= $COLNO) and
              ($ny >= 0) and ($ny <= $ROWNO) and
              ($map[$nx][$ny]{type} =~ /WALL|DOOR/)) {
            $wdirs += $wdir{$wd}{bit};
          }
        }
        $map[$x][$y] = +{ type => 'WALL',
                          char => ($wallglyph[$wdirs] || $map[$x][$y]{c} || '-'),
                          bg   => 'on_black',
                          fg   => 'yellow',
                        };
      }
    }
  }
  # Show the stairs.
  $map[$stairx][$stairy] = +{ type => 'STAIR',
                              char => '<',
                              fg   => 'white',
                              bg   => 'on_red',
                            };
  return \@map;
}

sub floodfill {
  my ($array, $cx, $cy, $oldvalue, $newvalue) = @_;
  if ($$array[$cx][$cy] eq $oldvalue) {
    $$array[$cx][$cy] = $newvalue;
    floodfill($array, $cx - 1, $cy, $oldvalue, $newvalue) if $cx > 1;
    floodfill($array, $cx + 1, $cy, $oldvalue, $newvalue) if $cx < ($COLNO - 1);
    floodfill($array, $cx, $cy - 1, $oldvalue, $newvalue) if $cy > 1;
    floodfill($array, $cx, $cy + 1, $oldvalue, $newvalue) if $cy < ($ROWNO - 1);
  }
}

sub undecided_spots_exist {
  my ($map) = @_;
  for my $x (2 .. ($COLNO - 2)) {
    for my $y (2 .. ($ROWNO - 2)) {
      if ($$map[$x][$y]{type} eq 'UNDECIDED') {
        return "Undecided spots exist, starting at ($x,$y).";
      }
    }
  }
  return;
}

sub countareas {
  my ($map, $typere) = @_;
  my $areaidx = 0;
  my @area = map {
    [ map { 0 } 0 .. $ROWNO]
  } 0 .. $COLNO;
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      $area[$x][$y] = ($$map[$x][$y]{type} =~ $typere) ? 0 : -1;
    }
  }
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      if (($$map[$x][$y]{type} =~ $typere) and
          ($area[$x][$y] eq 0)) {
        $areaidx++;
        print "countareas: found area $areaidx at ($x,$y)\n" if $debug > 1;
        floodfill(\@area, $x, $y, 0, $areaidx);
      }
    }
  }
  return $areaidx;
}

sub countadjacent {
  my ($map, $x, $y, $type) = @_;
  my $count = 0;
  for my $cx (($x - 1) .. ($x + 1)) {
    for my $cy (($y - 1) .. ($y + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count.
      } elsif (($cx < 1) or ($cx >= $COLNO) or
               ($cy < 1) or ($cy >= $ROWNO)) {
        # Out of bounds, doesn't count
      } elsif ($$map[$cx][$cy]{type} eq $type) {
        $count++;
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

sub rectangles_overlap {
  my ($rone, $rtwo) = @_;
  for my $x ($$rone{minx} .. $$rone{maxx}) {
    for my $y ($$rone{miny} .. $$rone{maxy}) {
      if (($x >= $$rtwo{minx}) and ($x <= $$rtwo{maxx}) and
          ($y >= $$rtwo{miny}) and ($y <= $$rtwo{maxy})) {
        return "Overlap it does, yes:  ($x, $y), both rectangles it is in.";
      }
    }
  }
  return;
}

sub closet_rectangle {
  my ($cx, $cy, $dx, $dy, $cnum, $doplace, $map, $secretdoor) = @_;
  my @closetbg = qw(on_black on_blue on_cyan on_green on_red on_magenta on_yellow);
  if ($debug > 2) {
    my $s = ($secretdoor) ? " secret" : "";
    my $verb = $doplace   ? "Placing" : "Considering";
    print "$verb$s closet ";
    print color "black " . ($closetbg[$cnum] || 'on_black');
    print $cnum;
    print color "reset";
    print " at ($cx,$cy), with door facing ($dx,$dy)\n";
  }
  my $ax = $cx + $dx * $minaccess;
  my $ay = $cy + $dy * $minaccess;
  my $bx = $cx;
  my $by = $cy;
  if ($ax > $bx) {
    ($ax, $bx) = ($bx, $ax);
  }
  if ($ay > $by) {
    ($ay, $by) = ($by, $ay);
  }
  $ax -= $minbuffer;
  $bx += $minbuffer;
  $ay -= $minbuffer;
  $by += $minbuffer;
  if ($debug > 3) {
    print " * Rectangle is from ($ax, $ay) to ($bx, $by).\n";
  }
  if ($doplace) {
    for my $x ($ax .. $bx) {
      for my $y ($ay .. $by) {
        my $type = ((((abs($x - $cx) == 1) and (abs($y - $cy) <= 1)) or
                     ((abs($y - $cy) == 1) and (abs($x - $cx) <= 1)) or
                     ((($x < $cx) or (($x - 1 <= $cx) and ($y != $cy))) and ($dx > 0)) or
                     ((($y < $cy) or (($y - 1 <= $cy) and ($x != $cx))) and ($dy > 0)) or
                     ((($x > $cx) or (($x + 1 >= $cx) and ($y != $cy))) and ($dx < 0)) or
                     ((($y > $cy) or (($y + 1 >= $cy) and ($x != $cx))) and ($dy < 0))) ?
                    ((($x == $cx + $dx) and ($y == $cy + $dy))
                     ? 'DOOR' : 'WALL') : 'ROOM');
        $$map[$x][$y] = +{
                          type => $type,
                          char => (($type eq 'DOOR') ? '+' :
                                   ($type eq 'WALL') ? 'X' : $floorchar),
                          fg   => (($type eq 'DOOR') ? ($secretdoor ? 'blue' : 'yellow') :
                                   ($type eq 'WALL') ? 'yellow' : 'yellow'),
                          bg   => 'on_black',#($closetbg[$cnum] || 'on_black'),
                         };
      }
    }
  } elsif ($debug > 4) {
    print " * Not placing on map.\n";
  }
  return { minx => $ax, miny => $ay,
           maxx => $bx, maxy => $by,
           cx   => $cx, cy   => $cy, };
}

sub appendhtml {
  my ($map) = @_;
  use HTML::Entities;
  open HTML, ">>", "mimic-of-the-mines-levels.xml";
  print HTML qq[<div class="leveltitle">Mimic of the Mines (Generated):</div>
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

