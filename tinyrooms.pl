#!/usr/bin/perl

my $debug     = 0;
my $wallprob  = 0;
my $tightpack = 5; # Higher values mean try harder to fill all the space.
my $usecolor  = 0;
my $floorchar = '·';

use strict;
use Term::ANSIColor;
#use Term::ANSIScreen qw(cls);

my $COLNO = 79;
my $ROWNO = 20;
my ($x, $y, $roomno, $jc, $jpc, $try) = (0, 0, 0, 0, 0, 0);
my @fg = qw(red green blue cyan yellow);

my %wdir = ( E => +{ bit => 1, dx =>  1, dy =>  0, clockwise => 'S', },
             N => +{ bit => 2, dx =>  0, dy => -1, clockwise => 'E', },
             W => +{ bit => 4, dx => -1, dy =>  0, clockwise => 'N', },
             S => +{ bit => 8, dx =>  0, dy =>  1, clockwise => 'W', },
           );
my @wallglyph = qw/! ─ │ └ ─ ─ ┘ ┴ │ ┌ │ ├ ┐ ┬ ┤ ┼/;
$wallglyph[0] = '-';


my @room;
my @map = map {
  [map { +{ type => 'UNDECIDED',
            char => ' ',
            fg   => 'white',
            bg   => 'on_black',
            rno  => undef,
          }
       } 0 .. $ROWNO],
} 0 .. ($COLNO);
for $x (0 .. $COLNO) {
  $map[$x][0] = +{ type => 'STONE',
                   rno  => undef,
                   char => ' ',
                   fg   => 'white',
                   bg   => 'on_black',
                 };
}
for $y (1 .. $ROWNO) {
  $map[0][$y] = +{ type => 'STONE',
                   rno  => undef,
                   char => ' ',
                   fg   => 'white',
                   bg   => 'on_black',
                 };
}

$|++ if $debug;
sub jot {
  my ($c, $force) = (@_);
  return if $debug < 3;
  $jc++;
  if ((not ($jc % 1000)) or $force) {
    print $c;
    $jpc++;
    if (not ($jpc % 60)) {
      print " ${jc} [$roomno / $try] ($x,$y)\n";
    }
  }
}

sub towardtoporleft {
  my ($dx, $dy) = (-1, 0);
  if (((($ROWNO + 5 <= $COLNO)) and
       ($ROWNO + 5 >= int rand $COLNO))
      or
      ((($COLNO + 5 <= $COLNO)) and
       ($COLNO - 5 <= int rand $ROWNO))
      or
      (($ROWNO + 5 > $COLNO) and
       ($COLNO + 5 > $ROWNO) and
       (50 > int rand 100))) {
    ($dx, $dy) = (0, -1);
  }
  return ($dx, $dy);
}

sub makecorr {
  my ($corrx, $corry, $group) = @_;
  if ($map[$corrx][$corry]{type} =~ /UNDECIDED|WALL/) {
    $map[$corrx][$corry] = +{
                             rno  => 0,
                             char => '#',
                             fg   => 'white',
                             bg   => '',
                             type => 'CORR',
                            };
    $room[0]{group} = $group;
  }
}

# Place as many rooms as possible...
my $addedany = 1;
my $looped   = 0;
print "\nPlacing floor areas...\n";
while ($addedany and ($looped++ < 9000)) {
  $addedany = 0;
  for $try (1 .. 10) {
    jot('O', 'force');
    my $hsize = 3 + int rand 3;
    my $vsize = 2 + int rand 2;
    # Start in the lower right corner...
    $x = $COLNO - $hsize - 1;
    $y = $ROWNO - $vsize - 1;
    # Fall toward the top left corner as far as possible...
    my $moved = 1;
    my $subloop = 0;
    while ($moved and ($subloop++ < $ROWNO + $COLNO)) {
      $moved = 0;
      for (1 .. 20) {
        if ($debug >= 7) { print " (($x,$y)) "; }
        my ($dx, $dy) = towardtoporleft();
        my ($nx, $ny) = ($x + $dx, $y + $dy);
        if (($nx == $x) and ($ny == $y)) {
          die "direction fail";
        }
        if (fits($nx, $ny, $hsize, $vsize)) {
          ($x, $y) = ($nx, $ny);
          $moved++;
          jot('.');
          if ($debug >= 7) { print " [[$dx,$dy]]"; }
        }
      }
      if ($debug >= 7) { <STDIN>; }
    }
    # Now pick a direction and try to wiggle around and squeeze
    # closer to that side...
    my ($dx, $dy) = towardtoporleft();
    # First, back off one tile, in case that lets us slip past an obstacle:
    if (fits($x - $dx, $y - $dy, $hsize, $vsize)) {
      $x -= $dx; $y -= $dy;
    }
    # Now try sliding around in the other dimension...
    for (1 .. $tightpack) {
      my $dir = (50 >= int rand 100) ? 1 : -1;
      # Note that we switch dx and dy here, to move in the perpendicular.
      my ($nx, $ny) = ($x + $dir * $dy, $y + $dir * $dx);
      if (fits($nx, $ny, $hsize, $vsize)) {
        jot('_');
        ($x, $y) = ($nx, $ny);
      }
      # And see if we can make headway...
      my ($nx, $ny) = ($x + $dx * 2, $y + $dy * 2);
      my $sltwo = 0;
      while (fits($nx, $ny, $hsize, $vsize) and ($sltwo++ < 100)) {
        jot('+', 'force');
        ($x, $y) = ($nx, $ny);
        ($nx, $ny) = ($x + $dx, $y + $dy);
      }
    }
    if (fits($x, $y, $hsize, $vsize)) {
      $addedany++;
      $roomno++;
      $room[$roomno] = {
                        rno => $roomno, group => $roomno,
                        x => $x, y => $y, xsize => $hsize, ysize => $vsize,
                       };
      jot('X', 'force');
      my $fgcolor = 'white'; #$fg[int rand @fg];
      my $dowalls = ($wallprob > int rand 100) ? 1 : 0;
      for my $xo (0 .. ($hsize - 1)) {
        for my $yo (0 .. ($vsize - 1)) {
          my ($type, $char, $bg) = ('ROOM', $floorchar, '');
          if ($dowalls) {
            if ($yo + 1 == $vsize) {
              ($type, $char, $bg) = ('WALL', '-', 'on_black');
            } elsif ($xo + 1 == $hsize) {
              ($type, $char, $bg) = ('WALL', '|', 'on_black');
            }
          }
          $map[$x + $xo][$y + $yo] =
            +{ type => $type,
               rno  => $roomno,
               char => $char,
               fg   => $fgcolor,
               bg   => $bg,
             };
        }
      }
      showmap() if $debug;
    }
  }
}
warn "Looped max number of times for floor placement.\n" if $looped >= 9000;
showmap() if $debug;
print "\nForming interconnections as necessary...\n";

# Connect the rooms with corridors as necessary:
my $groupcount   = $roomno;
$looped          = 0;
while (($groupcount > 1) and ($looped++ <= 2000)) {
  my $countchanged    = 1;
  my $changedanything = 0;
  my $slthree         = 0;
  while ($countchanged and $slthree++ < 500) {
    jot('.');
    my $oldcount = $groupcount;
    $groupcount = 0; $changedanything = 0;
    my @seen = map { 0 } 0 .. $roomno;
    for my $r (1 .. $roomno) {
      my $group = $room[$r]{group};
      my $oldgroup = $group;
      for $x (0 .. ($room[$r]{xsize} - 1)) {
        my $otherx = $room[$r]{x} + $x;
        my $othery = $room[$r]{y} - 1;
        if ($map[$otherx][$othery]{type} =~ /ROOM|CORR/) {
          my $otherno  = $map[$otherx][$othery]{rno};
          $group  = $room[$otherno]{group};
          $room[$r]{group} = $group;
          for my $groupmate (1 .. $roomno) {
            if ($room[$groupmate]{group} == $oldgroup) {
              $room[$groupmate]{group} = $group;
            }
          }
        }
      }
      for $y (0 .. ($room[$r]{ysize} - 1)) {
        my $othery = $room[$r]{y} + $y;
        my $otherx = $room[$r]{x} - 1;
        if ($map[$otherx][$othery]{type} =~ /ROOM|CORR/) {
          my $otherno = $map[$otherx][$othery]{rno};
          $group  = $room[$otherno]{group};
          $room[$r]{group} = $group;
          for my $groupmate (1 .. $roomno) {
            if ($room[$groupmate]{group} == $oldgroup) {
              $room[$groupmate]{group} = $group;
            }
          }
        }
      }
      if (not $seen[$group]) {
        $seen[$group]++;
        $groupcount++;
      }
    }
    $countchanged = ($groupcount == $oldcount) ? 0 : 1;
    if ($debug) {
      showmap();
    }
  }
  if ($slthree >= 500) {
    warn "\nslthree exceeded maximum\n";
  }
  print "Now: $groupcount groups of rooms ($roomno rooms total).\n" if $debug;
  my $groupone = $room[int rand $roomno]{group};
  my $grouptwo = $groupone;
  my $roomtwo  = 1;
  my $rno      = 1;
  my $slfour   = 0;
  while (($rno <= $roomno) and ($grouptwo == $groupone)
         and ($slfour++ < $ROWNO * $COLNO)) {
    $grouptwo = $room[$rno]{group};
    $roomtwo  = $rno;
    $rno++;
  }
  my $roomone = 1;
  for my $rno (1 .. $roomno) {
    if ($room[$rno]{group} == $groupone) {
      $roomone = $rno;
    }
  }
  my $startx = $room[$roomone]{x} + int rand $room[$roomone]{xsize};
  my $starty = $room[$roomone]{y} + int rand $room[$roomone]{ysize};
  my $endx   = $room[$roomtwo]{x} + int rand $room[$roomtwo]{xsize};
  my $endy   = $room[$roomtwo]{y} + int rand $room[$roomtwo]{ysize};
  if ($startx > $endx) {
    ($startx, $endx) = ($endx, $startx);
  }
  if ($starty > $endy) {
    ($starty, $endy) = ($endy, $starty);
  }
  if (50 > int rand 100) {
    # horizontal first
    for $x ($startx .. $endx) {
      makecorr($x, $starty, $groupone);
    }
    for $y ($starty .. $endy) {
      makecorr($endx, $y, $groupone);
    }
  } else {
    # vertical first
    for $y ($starty .. $endy) {
      makecorr($startx, $y, $groupone);
    }
    for $x ($startx .. $endx) {
      makecorr($x, $endy, $groupone);
    }
  }
  if ($debug > 3) {
    showmap();
    <STDIN>;
  }
}
warn "Looped max number of times for connectivity.\n" if $looped >= 2000;
print "\nConsidering orientation...\n";

# Because the algorithm produces asymetrical maps, sometimes we want to flip it:
if (50 > int rand 100) {
  @map = reverse @map;
}
if (50 > int rand 100) {
  for my $x (1 .. $COLNO) {
    $map[$x] = [reverse @{$map[$x]}];
  }
}
showmap() if $debug;
print "\nConverting corridors to room floor where appropriate...\n";

# Clean up corridors that should be room floor:
my $morecleanup = 1;
$looped = 0;
while ($morecleanup and ($looped <= 9000)) {
  $morecleanup = 0;
  for $x (1 .. ($COLNO - 1)) {
    for $y (1 .. ($ROWNO - 1)) {
      if (($map[$x][$y]{type} eq 'CORR') and
          (orthocount($x,$y, qr/ROOM|CORR/) >= 3) and
          (orthocount($x,$y, qr/ROOM/) >= 1)) {
        # Clean up situations like this:
        #  .....
        #  ..#..
        #  -----
        $map[$x][$y] = +{ rno  => 0,
                          char => $floorchar,
                          fg   => 'white',
                          bg   => '',
                          type => 'ROOM',
                        };
        $morecleanup++;
      } elsif ($map[$x][$y]{type} eq 'CORR') {
        # Clean up situations like this:
        #  ---
        # |#..
        # |...
        for my $wdone (keys %wdir) {
          my $wdtwo  = $wdir{$wdone}{clockwise};
          # Because wdone and wdtwo are ortho, the direction between can
          # be trivially calculated as the sum of their dx and dy values:
          my $diagdx = $wdir{$wdone}{dx} + $wdir{$wdtwo}{dx};
          my $diagdy = $wdir{$wdone}{dy} + $wdir{$wdtwo}{dy};
          if (($map[$x + $wdir{$wdone}{dx}][$y + $wdir{$wdone}{dy}]{type} eq 'ROOM') and
              ($map[$x + $wdir{$wdtwo}{dx}][$y + $wdir{$wdtwo}{dy}]{type} eq 'ROOM') and
              ($map[$x + $diagdx][$y + $diagdy]{type} eq 'ROOM')) {
            $map[$x][$y] = +{ rno  => 0,
                              char => $floorchar,
                              fg   => 'white',
                              bg   => '',
                              type => 'ROOM',
                            };
            $morecleanup++;
          }
        }
      }
    }
  }
  if ($debug > 2) {
    showmap();
  }
}
warn "Looped max number of times for corridor cleanup.\n" if $looped >= 9000;
showmap() if $debug;
print "\nCreating doors...\n";

# Add doors where appropriate:
for $x (1 .. ($COLNO - 1)) {
  for $y (1 .. ($ROWNO - 1)) {
    if ($map[$x][$y]{type} eq 'CORR') {
      my $owc = orthocount($x,$y, qr/STONE|UNDECIDED|WALL|DOOR/);
      my $ofc = orthocount($x,$y, qr/ROOM/);
      # We're looking for situations where the door will (after
      # cleanup) have exactly two orthogonally adjacent wall tiles,
      # opposite one another (we don't care about the diagonals), and
      # of the two orthogonally-adjacent non-wall tiles, at least one
      # of them is room floor.
      if (($owc == 2) and ($ofc >= 1)) {
        if ((($map[$x - 1][$y]{type} =~ /STONE|UNDECIDED|WALL/) and
             ($map[$x + 1][$y]{type} =~ /STONE|UNDECIDED|WALL/)) or
            (($map[$x][$y - 1]{type} =~ /STONE|UNDECIDED|WALL/) and
             ($map[$x][$y + 1]{type} =~ /STONE|UNDECIDED|WALL/))) {
          $map[$x][$y] = +{ type => 'DOOR',
                            char => '+',
                            bg   => 'on_black',
                            fg   => 'yellow',
                          };
        }
      }
    }
  }
}

print "\nCleaning up isolated corridors...\n";
# After adding doors, isolated corridor tiles adjacent to a door, which
# are also adjacent to at least one room tile, should be converted.
for $x (1 .. ($COLNO - 1)) {
  for $y (1 .. ($ROWNO - 1)) {
    if ($map[$x][$y]{type} eq 'CORR') {
      my $odc = orthocount($x,$y, qr/DOOR/);
      my $ofc = orthocount($x,$y, qr/ROOM/);
      if (($odc == 1) and ($ofc >= 1)) {
        $map[$x][$y] = +{ type => 'ROOM',
                          char => $floorchar,
                          fg   => 'white',
                          bg   => 'on_black',
                        };
      }
    }
  }
}

showmap() if $debug;

# Ok, time to consider whether there should be any walls...
for $x (0 .. $COLNO) {
  for $y (0 .. $ROWNO) {
    if ($map[$x][$y]{type} =~ /STONE|UNDECIDED|WALL/) {
      if (adjcount($x, $y, qr/ROOM/)) {
        $map[$x][$y] = +{
                         type => 'WALL',
                         char => '-',
                         bg   => 'on_black',
                         fg   => 'white',
                        };
      } else {
        $map[$x][$y] = +{ type => 'STONE',
                          char => ' ',
                          bg   => 'on_black',
                          fg   => 'black',
                        };
      }
    }
  }
}
for $x (0 .. $COLNO) {
  for $y (0 .. $ROWNO) {
    fixwalldirs($x, $y);
  }
}

showmap();

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

sub fixwalldirs {
  my ($x, $y) = @_;
  if ($map[$x][$y]{type} =~ /WALL/) {
    my $wdirs = 0;
    for my $wd (keys %wdir) {
      my $neighbor = neighbor($x, $y, $wd);
      if ($neighbor and (($$neighbor{type} =~ /WALL|DOOR/))) {
        $wdirs += $wdir{$wd}{bit};
      }
    }
    $map[$x][$y] = +{ type => 'WALL',
                      char => ($wallglyph[$wdirs] || $map[$x][$y]{c} || '-'),
                      bg   => 'on_black',
                      fg   => 'white',
                    };
  }
}

sub adjcount {
  my ($cx, $cy, $re) = @_;
  $re ||= qr/ROOM/;
  my $count = 0;
  for my $x (($cx - 1) .. ($cx + 1)) {
    for my $y (($cy - 1) .. ($cy + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count
      } elsif (($x < 1) or ($x >= $COLNO) or
               ($y < 1) or ($y >= $ROWNO)) {
        # Out of bounds, doesn't count
      } elsif ($map[$x][$y]{type} =~ $re) {
        $count++;
      }
    }
  }
  return $count;
}

sub orthocount {
  my ($cx, $cy, $re) = @_;
  $re ||= qr/ROOM/;
  my $count = 0;
  for my $x (($cx - 1) .. ($cx + 1)) {
    for my $y (($cy - 1) .. ($cy + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count
      } elsif (($x < 0) or ($x > $COLNO) or
               ($y < 0) or ($y > $ROWNO)) {
        # Out of bounds, doesn't count
      } elsif (abs($cx - $x) and abs($cy - $y)) {
        # Diagonal doesn't count as ortho
      } elsif ($map[$x][$y]{type} =~ $re) {
        $count++;
      }
    }
  }
  return $count;
}

sub fits {
  my ($px, $py, $xsize, $ysize) = @_;
  for my $dx (0 .. ($xsize - 1)) {
    for my $dy (0 .. ($ysize - 1)) {
      if (($px + $dx < 1) or
          ($px + $dx >= $COLNO) or
          ($py + $dy < 1) or
          ($py + $dy >= $ROWNO)) {
        if ($debug >= 9) { print " [oob:" . ($px + $dx) . "," . ($py + $dy) . "] "; }
        return; # Out of bounds
      }
      my $tile = $map[$px + $dx][$py + $dy];
      if ($$tile{type} =~ /WALL|ROOM|CORR/) {
        if ($debug >= 9) { print " [pos.occ:" . ($px + $dx) . "," . ($py + $dy) . ":$$tile{type}] "; }
        return; # Position occupied
      }
    }
  }
  if ($debug >= 9) { print " [fits:$px,$py,$xsize,$ysize] "; }
  return +{ fits => 'yes',
            minx => $px, miny => $py,
            maxx => $px + $xsize - 1,
            maxy => $py + $ysize - 1,
          };
}

sub showmap {
  #print cls();
  print "\n\n";
  for my $cy (0 .. $ROWNO) {
    for my $cx (0 .. $COLNO) {
      #if ($map[$cx][$cy]{type} eq 'ROOM') {
      #  my $clr = $fg[$room[$map[$cx][$cy]{rno}]{group} % scalar @fg];
      #  print color "$clr $map[$cx][$cy]{bg}" if $usecolor;
      #} else {
      print color "$map[$cx][$cy]{fg} $map[$cx][$cy]{bg}" if $usecolor;
      #}
      if (($debug > 5) and ($map[$cx][$cy]{type} =~ /ROOM|CORR/)) {
        my $rno = $map[$cx][$cy]{rno};
        print($room[$rno]{group} % 10);
        print color "reset" if $usecolor;
      #} elsif ($map[$cx][$cy]{char} eq '#') {
      #  print orthocount($cx,$cy, qr/ROOM/);
      } else {
        print $map[$cx][$cy]{char};
      }
    }
    print color "reset" if $usecolor;
    print "\n";
  }
  print "\n\n";
  if ($debug > 3) {
    <STDIN>;
  }
}




