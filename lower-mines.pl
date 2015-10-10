#!/usr/bin/perl

use utf8;
use open ':encoding(UTF-8)';
use open ":std";

my $debug        = 0;#3;
my $usecolor     = 1;
my $numofclosets = 2 + int rand 5;
my $minbuffer    = 2;
my $minaccess    = 4; # minbuffer + minaccess MUST be strictly less, preferably significantly less, than COLNO or ROWNO.
my $COLNO        = 79;#90;#79;
my $ROWNO        = 20;#35;#20;
my $floorchar    = '·';
my $buffersolidp = 30 + int rand 60; # probability for diagonal buffers to close up their gaps.
my $fgrowfigure  = 6 + int rand 12;  # floor areas grow if countortho(... 'ROOM') > int rand $fgrowfigure
my $wgrowfigure  = 10 + (int rand 30) + 3 * $numofclosets; # similar, but for walls
my $sgrowfigure  = 12; # similar, but for stone (which grows wall, not more stone)
my $vaultprob    = 50;
my $undozones    = int rand 2;# + int rand int($ROWNO * $COLNO / 800);
my $stoneblobs   = 5 + int rand int($ROWNO * $COLNO / 200); # likely some will fail
my $undogrowprob = 50 + int rand 30;
my $undoturnprob = 20 + int rand 50;
my $undothickenp = 50 + int rand 30;
my $maxthickness = 2 + int rand 5;
my $extraseeds   = 6 - (int rand $numofclosets);
my $vaultwhere   = "";

if ($undothickenp < $undogrowprob) {
  ($undothickenp, $undogrowprob) = ($undogrowprob, $undothickenp);
}

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
print qq[
numofclosets: $numofclosets
minbuffer:    $minbuffer
minaccess:    $minaccess
COLNO:        $COLNO
ROWNO:        $ROWNO
stoneblobs:   $stoneblobs
fgrowfigure:  $fgrowfigure
wgrowfigure:  $wgrowfigure
sgrowfigure:  $sgrowfigure
vaultprob:    $vaultprob
buffersolidp: $buffersolidp
undozones:    $undozones
undogrowprob: $undogrowprob
undoturnprob: $undoturnprob
undothickenp: $undothickenp
maxthickness: $maxthickness
extraseeds:   $extraseeds
] if $debug;
showmap($map);
appendhtml($map);
exit 0; # subroutines follow

sub generate {
  my @closet = map { undef } 1 .. $numofclosets;
  my ($stairx, $stairy);
  my $vaultsplaced = 0; # incremetns only when one is actually placed.
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
                     $cnum, 'doplace', \@map, 'secret');
    showmap(\@map) if $debug > 4;
  }
  $stairx = $closet[$numofclosets - 1]{cx} + ($closet[$numofclosets - 1]{dx} * $minaccess);
  $stairy = $closet[$numofclosets - 1]{cy} + ($closet[$numofclosets - 1]{dy} * $minaccess);

  # Maybe place a vault:
  if ($vaultprob >= int rand 100) {
    print "Attempting to find a place for a vault" if $debug > 1;
    my $tries = 0;
    my ($x, $y);
    while ((not $tries) or
           (($tries < 25) and
            (not canfitvault(\@map, $x, $y)))) {
      $tries++;
      print "." if $debug > 2;
      $x = $minbuffer + int rand rand rand($COLNO - (2 * $minbuffer) - 6);
      $y = $minbuffer + int rand rand rand($ROWNO - (2 * $minbuffer) - 6);
      if (50 < int rand 100) {
        $x = $COLNO - $x;
      }
      if (50 < int rand 100) {
        $y = $ROWNO - $y;
      }
    }
    if (canfitvault(\@map, $x, $y)) {
      for my $vx ($x .. ($x + 5)) {
        for my $vy ($y .. ($y + 5)) {
          $map[$vx][$vy] = +{ type => 'STONE',
                              char => ' ',
                              fg   => ($debug ? 'white' : 'yellow'),
                              bg   => 'on_black',
                            };
        }
      }
      for my $vx (($x + 2) .. ($x + 3)) {
        for my $vy (($y + 2) .. ($y + 3)) {
          $map[$vx][$vy] = +{ type => 'ROOM',
                              char => $floorchar,
                              fg   => 'white',
                              bg   => 'on_black', };
        }
      }
      $vaultsplaced++;
      $vaultwhere .= " from ($x, $y) to (".($x+5).",".($y+5).");";
    }
    print "\n" if $debug > 1;
  }

  # Throw in some more "floor areas" as seeds for growth...
  for (1 .. $extraseeds) {
    if (35 > (int rand 100)) {
      my ($x, $y) = (0, 0);
      while ($map[$x][$y]{type} ne 'UNDECIDED') {
        $x = int($COLNO / 10) + int rand ($COLNO * 8 / 10);
        $y = int($ROWNO / 10) + int rand ($ROWNO * 8 / 10);
      }
      my $dx = ($x > ($COLNO / 2)) ? -1 : 1;
      my $dy = ($x > ($ROWNO / 2)) ? -1 : 1;
      # npj
      # ABk
      # fCDm
      # ghEX <-- X == next A
      #  qrs
      while (($map[$x][$y]{type} eq 'UNDECIDED') and                  # A
             ($map[$x][$y + $dy]{type} eq 'UNDECIDED') and            # f
             ($map[$x][$y + 2 * $dy]{type} eq 'UNDECIDED') and        # g

             ($map[$x + $dx][$y]{type} eq 'UNDECIDED') and            # B
             ($map[$x + $dx][$y + $dy]{type} eq 'UNDECIDED') and      # C
             ($map[$x + $dx][$y + 2 * $dy]{type} eq 'UNDECIDED') and  # h

             ($map[$x + 2 * $dx][$y]{type} eq 'UNDECIDED') and        # k
             ($map[$x + 2 * $dx][$y + $dy]{type} eq 'UNDECIDED') and  # D
             ($map[$x + 2 * $dx][$y + 2 * $dy]{type} eq 'UNDECIDED')  # E

             # and ($map[$x + 3 * $dx][$y + $dy]{type} eq 'UNDECIDED')     # m
             # and ($map[$x + 3 * $dx][$y + 2 * $dy]{type} eq 'UNDECIDED') # next A
            ) {
        my $fg = $debug ? 'cyan' : 'yellow';
        # A = the position itself.
        $map[$x][$y] = +{ type => 'STONE',
                          char => 'H',
                          fg   => $fg,
                          bg   => 'on_black',
                        };
        # B = x+1
        $map[$x + $dx][$y] = +{ type => 'STONE',
                                char => 'H',
                                fg   => $fg,
                                bg   => 'on_black',
                              };
        # C = x+1, y+1
        $map[$x + $dx][$y + $dy] = +{ type => 'STONE',
                                      char => 'H',
                                      fg   => $fg,
                                      bg   => 'on_black',
                                    };
        # f = x, y+1
        $map[$x][$y + $dy] = +{ type => 'ROOM',
                                char => $floorchar,
                                fg   => $fg,
                                bg   => 'on_black',
                              };
        # g = x, y+2
        $map[$x][$y + 2 * $dy] = +{ type => 'ROOM',
                                    char => $floorchar,
                                    fg   => $fg,
                                    bg   => 'on_black',
                                  };
        # h = x+1, y+2
        $map[$x + $dx][$y + 2 * $dy] = +{ type => 'ROOM',
                                          char => $floorchar,
                                          fg   => $fg,
                                          bg   => 'on_black',
                                        };
        if (($map[$x + (2 * $dx)][$y - $dy]{type} eq 'UNDECIDED') and       # j
            ($map[$x + (3 * $dx)][$y + $dy]{type} eq 'UNDECIDED') and       # m
            ($map[$x + (3 * $dx)][$y + (2 * $dy)]{type} eq 'UNDECIDED') and # X == next A
            ($map[$x + $dx][$y + (3 * $dy)]{type} eq 'UNDECIDED') and       # q
            ($map[$x + (2 * $dx)][$y + (3 * $dy)]{type} eq 'UNDECIDED') and # r
            ($map[$x + (3 * $dx)][$y + (3 * $dy)]{type} eq 'UNDECIDED') and # s
            ($buffersolidp > int rand 100)
           ) {
          $map[$x + 2 * $dx][$y + $dy] = +{ type => 'WALL',    # D
                                            char => $floorchar,
                                            fg   => $fg,
                                            bg   => 'on_black',
                                          };
          $map[$x + 2 * $dx][$y + 2 * $dy] = +{ type => 'WALL', # E
                                                char => $floorchar,
                                                fg   => $fg,
                                                bg   => 'on_black',
                                              };
          $map[$x + 2 * $dx][$y - $dy] = +{ type => 'ROOM', # j
                                            char => $floorchar,
                                            fg   => $fg,
                                            bg   => 'on_black',
                                          };
          $map[$x + 2 * $dx][$y] = +{ type => 'ROOM', # k
                                      char => $floorchar,
                                      fg   => $fg,
                                      bg   => 'on_black',
                                    };
          $map[$x + $dx][$y + 3  * $dy] = +{ type => 'ROOM', # q
                                             char => $floorchar,
                                             fg   => $fg,
                                             bg   => 'on_black',
                                           };
          $map[$x + 2 * $dx][$y + 3  * $dy] = +{ type => 'ROOM', # r
                                                 char => $floorchar,
                                                 fg   => $fg,
                                                 bg   => 'on_black',
                                               };
        }
        # n = x, y-1
        if ($map[$x][$y - $dy]{type} eq 'UNDECIDED') {
          $map[$x][$y - $dy] = +{ type => 'ROOM',
                                  char => $floorchar,
                                  fg   => $fg,
                                  bg   => 'on_black',
                                };
        }
        # p = x+1, y-1
        if ($map[$x + $dx][$y - $dy]{type} eq 'UNDECIDED') {
          $map[$x + $dx][$y - $dy] = +{ type => 'ROOM',
                                        char => $floorchar,
                                        fg   => $fg,
                                        bg   => 'on_black',
                                      };
        }
        $x += $dx * 3;
        $y += $dy * 2;
      }
    } else {
      my $x = $minbuffer + 1 + int rand ($COLNO - 3 * ($minbuffer + 1));
      my $y = $minbuffer + 1 + int rand ($ROWNO - 3 * ($minbuffer + 1));
      for my $dx (0 .. $minbuffer + 1) {
        for my $dy (0 .. $minbuffer + 1) {
          if ($map[$x + $dx][$y + $dy]{type} eq 'UNDECIDED') {
            if (($dx >= 1) and ($dx <= 2) and
                ($dy >= 1) and ($dy <= 2)) {
              $map[$x + $dx][$y + $dy] = +{
                                           type => 'STONE',
                                           char => ' ',
                                           fg   => ($debug ? 'green' : 'yellow'),
                                           bg   => 'on_black',
                                          };
            } else {
              $map[$x + $dx][$y + $dy] = +{
                                           type => 'ROOM',
                                           char => $floorchar,
                                           fg   => ($debug ? 'green' : 'yellow'),
                                           bg   => 'on_black',
                                          };
            }
          }
        }
      }
    }
  }

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
  while (($areas > 1 + $vaultsplaced) or (count_terrain(\@map, qr/UNDECIDED/) > ($COLNO * $ROWNO / 10))) {
    if ($tries++ > (4 * $ROWNO * $COLNO)) {
      warn "Spent too long attempting to connect areas.  Restarting...\n" if $debug;
      return generate();
    } elsif (not undecided_spots_exist(\@map)) {
      showmap(\@map) if $debug > 1;
      warn "Ran out of undecided areas.  Restarting...\n" if $debug;
      return generate();
    }
    for my $p (0 .. ($numofpositions - 1)) {
      my ($x, $y) = ($posn[$p]{x}, $posn[$p]{y});
      if ($map[$x][$y]{type} eq 'UNDECIDED') {
        if (countortho(\@map, $x, $y, 'ROOM') > int rand $fgrowfigure) {
          $map[$x][$y] = +{ type => 'ROOM',
                            char => $floorchar,
                            fg   => 'yellow',
                            bg   => 'on_black',
                          };
          ($stairx, $stairy) = ($x, $y);
        } elsif ((countortho(\@map, $x, $y, 'WALL')  > int rand ($wgrowfigure)) or
                 (countortho(\@map, $x, $y, 'STONE') > int rand $sgrowfigure)) {
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
  if (count_terrain(\@map, qr/ROOM/) < ($COLNO * $ROWNO * 2 / 5)) {
    showmap(\@map) if $debug;
    warn "Not enough floor, starting over.\n" if $debug;
    return generate();
  }

  showmap(\@map) if $debug;

  print "Placing stone blobs.\n" if $debug;
  for (1 .. $stoneblobs) {
    my $xsize = 5 + int rand int($COLNO / 5);
    my $ysize = 3 + int rand int($ROWNO / 4);
    my $startx = $minbuffer + int rand($COLNO - (2 * $minbuffer) - $xsize);
    my $starty = $minbuffer + int rand($ROWNO - (2 * $minbuffer) - $ysize);
    my $tries;
    print " * Attemping to place $xsize x $ysize stone blob.\n" if $debug > 1;
    while ((not spaceforblob(\@map, $startx, $starty,
                                    $startx + $xsize - 1, $starty + $ysize - 1,
                                    $stairx, $stairy)) and
          ($tries++ <= 100)) {
      $startx = $minbuffer + int rand($COLNO - (2 * $minbuffer) - $xsize);
      $starty = $minbuffer + int rand($ROWNO - (2 * $minbuffer) - $ysize);
    }
    if ($tries < 99) {
      my $endx = $startx + $xsize - 1;
      my $endy = $starty + $ysize - 1;
      my $cx = int(($startx + $endx) / 2);
      my $cy = int(($starty + $endy) / 2);
      my $maxdist = int sqrt((($cx - $startx) * ($cx - $startx)) + (($cy - $starty) * ($cy - $starty)));
      print "    * From ($startx,$starty), center at ($cx,$cy), to ($endx,$endy), maxdist $maxdist\n" if $debug;
      for my $x ($startx .. $endx) {
        for my $y ($starty .. $endy) {
          my $dist = sqrt((($x - $cx) * ($x - $cx)) + (($y - $cy) * ($y - $cy)));
          if (($dist < int($maxdist / 2)) or
              ($dist < int(((int rand $maxdist) + (int rand $maxdist)) / 2))) {
            $map[$x][$y] = +{ type => 'STONE',
                              char => 'U',
                              fg   => ($debug ? 'red' : 'yellow'),
                              bg   => 'on_black',
                            };
          }
        }
      }
    } elsif ($debug > 1) {
      print "    * FAILED.\n";
    }
  }
  showmap(\@map) if $debug > 1;

  print "Placing $undozones undo zones.\n" if $debug;
  for (1 .. $undozones) {
    my ($ux, $uy, $dx, $dy, $tries) = (0,0,0,0,0);
    while (($tries++ < 30) and not validundozone(\@map, $ux, $uy, $dx, $dy, $stairx, $stairy)) {
      $ux = $minbuffer + int rand ($COLNO - (2 * $minbuffer));
      $uy = $minbuffer + int rand ($ROWNO - (2 * $minbuffer));
      $dx = (int rand 3) - 1;
      $dy = $dx ? 0 : ((50 > int rand 100) ? -1 : 1);
    }
    recursiveundo(\@map, $ux, $uy, $dx, $dy, $stairx, $stairy);
    $map[$ux][$uy]{fg} = 'cyan' if $debug;
  }
  showmap(\@map) if $debug > 1;

  # Maybe do a vault.
  #if ($vaultprob >= int rand 100) {
  #  print "Attempting to find a place for a vault" if $debug > 1;
  #  my $tries = 0;
  #  my ($x, $y);
  #  while ((not $tries) or
  #         (($tries < 50) and
  #          (not canfitvault(\@map, $x, $y)))) {
  #    $tries++;
  #    print "." if $debug > 2;
  #    $x = $minbuffer + int rand($COLNO - (2 * $minbuffer) - 6);
  #    $y = $minbuffer + int rand($ROWNO - (2 * $minbuffer) - 6);
  #  }
  #  if (canfitvault(\@map, $x, $y)) {
  #    for my $vx (($x + 2) .. ($x + 3)) {
  #      for my $vy (($y + 2) .. ($y + 3)) {
  #        $map[$vx][$vy] = +{ type => 'ROOM',
  #                            char => $floorchar,
  #                            fg   => 'white',
  #                            bg   => 'on_black', };
  #      }
  #    }
  #  }
  #  print "\n" if $debug > 1;
  #}

  # Fix up stone versus wall.
  for my $x (0 .. ($COLNO)) {
    for my $y (0 .. ($ROWNO)) {
      my $fg = $map[$x][$y]{fg} || 'yellow';
      if ($map[$x][$y]{type} =~ /STONE|WALL|UNDECIDED/) {
        if (countadjacent(\@map, $x, $y, 'ROOM')) {
          $map[$x][$y] = +{ type => 'WALL',
                            char => '-',
                            bg   => 'on_black',
                            fg   => $fg,
                          };
        } else {
          $map[$x][$y] = +{ type => 'STONE',
                            char => ' ',
                            bg   => 'on_black',
                            fg   => $fg,
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
        my $fg = $map[$x][$y]{fg};
        $map[$x][$y] = +{ type => 'WALL',
                          char => ($wallglyph[$wdirs] || $map[$x][$y]{c} || '-'),
                          bg   => 'on_black',
                          fg   => $fg,
                        };
      }
    }
  }
  # Add the stairs.
  $map[$stairx][$stairy] = +{ type => 'STAIR',
                              char => '<',
                              fg   => 'white',
                              bg   => 'on_red',
                            };
  while (($map[$stairx][$stairy]{type} ne 'ROOM') or
         (countortho(\@map, $stairx, $stairy, 'ROOM') < 4)) {
    $stairx = $minbuffer + int rand ($COLNO - 2 * $minbuffer);
    $stairy = $minbuffer + int rand ($ROWNO - 2 * $minbuffer);
  }
  $map[$stairx][$stairy] = +{ type => 'STAIR',
                              char => '>',
                              fg   => 'white',
                              bg   => 'on_red',
                            };
  return \@map;
}

sub spaceforblob {
  my ($map, $startx, $starty, $endx, $endy, $stairx, $stairy) = @_;
  for my $x (($startx - 1) .. ($endx + 1)) {
    for my $y (($starty - 1) .. ($endy + 1)) {
      if (($x <= 0) or ($x >= $COLNO) or
          ($y <= 0) or ($y >= $COLNO) or
          (($x == $stairx) and ($y == $stairy)) or
          (not ($$map[$x][$y]{type} =~ /ROOM/))) {
        return;
      }
    }
  }
  return "Yes, there seems to be room for a blob there.";
}

sub recursiveundo {
  my ($map, $cx, $cy, $dx, $dy, $stairx, $stairy) = @_;
  my $fg = ($debug) ? 'magenta' : 'yellow';
  if (validundozone($map, $cx, $cy, $dx, $dy, $stairx, $stairy)) {
    $$map[$cx][$cy] = +{ type => 'STONE',
                         char => 'X',
                         fg   => $fg,
                         bg   => 'on_black',
                       };
    my $x = $cx + $dx;
    my $y = $cy + $dy;
    if ($undogrowprob > int rand 100) {
      recursiveundo($map, $x, $y, $dx, $dy, $stairx, $stairy);
    } elsif (($cx > $minbuffer) and ($cx + 2 * $minbuffer < $COLNO) and
             ($cy > $minbuffer) and ($cy + 2 * $minbuffer < $COLNO)) {
      if ($undoturnprob > int rand 100) {
        recursiveundo($map, $cx - 1, $cy, -1, 0, $stairx, $stairy);
      }
      if ($undoturnprob > int rand 100) {
        recursiveundo($map, $cx + 1, $cy, 1, 0, $stairx, $stairy);
      }
      if ($undoturnprob > int rand 100) {
        recursiveundo($map, $cx, $cy - 1, 0, -1, $stairx, $stairy);
      }
      if ($undoturnprob > int rand 100) {
        recursiveundo($map, $cx, $cy + 1, 0, 1, $stairx, $stairy);
      }
    }
  }
  my $thickness = 0;
  while (($undothickenp > int rand 100) and ($thickness < $maxthickness)) {
    $thickness++;
    if ((($cx + ($thickness + 1) * $dy) > 0) and
        (($cx + ($thickness + 1) * $dy) < $COLNO) and
        (($cy + ($thickness + 1) * $dx) > 0) and
        (($cy + ($thickness + 1) * $dx) < $ROWNO)) {
      if (($$map[$cx + $thickness * $dy][$cy + $thickness * $dx]{type} =~ /ROOM|UNDECIDED/) and
          ($$map[$cx + ($thickness + 1) * $dy][$cy + ($thickness + 1) * $dx]{type} =~ /ROOM/)) {
        $$map[$cx + $thickness * $dy][$cy + $thickness * $dx] = +{
                                                                  type => 'WALL',
                                                                  char => 'X',
                                                                  fg   => ($debug ? 'white' : 'yellow'),
                                                                  bg   => 'on_black',
                                                                 };
      }
    }
  }
}

sub validundozone {
  my ($map, $cx, $cy, $dx, $dy, $stairx, $stairy) = @_;
  if (($cx < 2) or ($cx >= ($COLNO - 1)) or
      ($cy < 1) or ($cy >= $ROWNO)) {
    return;
  }
  if ($$map[$cx][$cy]{type} ne 'ROOM') {
    return;
  }
  if (($cx == $stairx) and ($cy == $stairy)) {
    return;
  }
  my $startx = $cx + $dx;
  my $starty = $cy + $dy;
  my $endx   = $cx + 4 * $dx;
  my $endy   = $cy + 3 * $dy;
  if ($startx > $endx) {
    ($startx, $endx) = ($endx, $startx);
  } elsif ($startx == $endx) {
    $startx--;
    $endx++;
  }
  if ($starty > $endy) {
    ($starty, $endy) = ($endy, $starty);
  } elsif ($starty == $endy) {
    $starty--;
    $endy++;
  }
  for my $x ($startx .. $endx) {
    for my $y ($starty .. $endy) {
      if (($x >= 0) and ($x <= $COLNO) and
          ($y >= 0) and ($y <= $ROWNO) and
          (not ($$map[$x][$y]{type} =~ /ROOM/))) {
        return;
      }
      if (($x == $stairx) and ($y == $stairy)) {
        return;
      }
    }
  }
  return "Sure, that looks like a valid undo zone to me.";
}

sub canfitvault {
  my ($map, $x, $y) = @_;
  for my $vx ($x .. ($x + 5)) {
    for my $vy ($y .. ($y + 5)) {
      if (not ($$map[$vx][$vy]{type} =~ /UNDECIDED|STONE|WALL/)) {
        return;
      }
    }
  }
  return "yes, can fit a vault at ($x,$y)";
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

sub count_terrain {
  my ($map, $re) = @_;
  my $count = 0;
  for my $x (2 .. ($COLNO - 2)) {
    for my $y (2 .. ($ROWNO - 2)) {
      if ($$map[$x][$y]{type} =~ $re) {
        $count++;
      }
    }
  }
  return $count;
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
        print "countareas: found area $areaidx at ($x,$y)\n" if $debug > 4;
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
    print "$verb$s closet $cnum at ($cx,$cy), with door facing ($dx,$dy)\n"
      if $debug > ($doplace ? 2 : 4);
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
                                   ($type eq 'WALL') ? 'yellow' : ($debug ? 'red' : 'yellow')),
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

