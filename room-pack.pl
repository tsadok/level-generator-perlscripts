#!/usr/bin/perl

use Term::ANSIColor;

my ($ROWNO, $COLNO) = (21, 79);

my (@rowpos, @colpos, @grid, @cell, @map,
    $rowcount, $colcount, $cellcount, $cellcount);
my ($x, $y, $trycount);
my ($trymax, $xpandprob) = (7000, 60);
my $targetpct = 60 + int rand 30;

$x = 0;
while (++$x + 6 < $COLNO) {
  $colcount++;
  $colpos[$colcount - 1] = $x;
  $x += 2 + int rand 4;
}
$colpos[$colcount] = $COLNO - 2;

$y = 0;
while (++$y + 4 < $ROWNO) {
  $rowcount++;
  $rowpos[$rowcount - 1] = $y;
  $y += 2 + int rand 2;
}
$rowpos[$rowcount] = $ROWNO - 2;

$cellmax = $rowcount * $colcount;

for $x (1 .. $colcount) {
  for $y (1 .. $rowcount) {
    $grid[$x - 1][$y - 1] = 0;
  }
}

while ((($gridcellcount * 100 / $cellmax) < $targetpct) and
       ($trycount < $trymax)) {
  $x = int rand $colcount;
  $y = int rand $rowcount;
  if ($grid[$x][$y]) {
    $trycount++;
  } else {
    my ($minx, $maxx, $miny, $maxy) = ($x, $x, $y, $y);
    $cellcount++;
    $gridcellcount++;
    $grid[$x][$y] = $cellcount;
    my $trytoexpand = sub {
      my ($xdir, $ydir) = @_;
      print "  Attempting to expand ($xdir,$ydir) ";
      while ($xpandprob > int rand 100) {
        my $canexpand = 1;
        if ($xdir != 0) {
          for $y ($miny .. $maxy) {
            if (($maxx + $xdir >= $colcount) or
                ($minx + $xdir < 0) or
                $grid[$maxx + $xdir][$y] or
                $grid[$minx + $xdir][$y]) {
              $canexpand = 0;
            }
          }
          if ($canexpand) {
            print "x";
            if ($xdir > 0) {
              $maxx += $xdir;
            } else {
              $minx += $xdir;
            }
            for $y ($miny .. $maxy) {
              $grid[$minx][$y] = $cellcount;
              $grid[$maxx][$y] = $cellcount;
              $gridcellcount++;
            }
          } else {
            print "0";
          }
        } else {
          for $x ($minx .. $maxx) {
            if (($maxy + $ydir >= $rowcount) or
                ($miny + $ydir < 0) or
                $grid[$x][$miny + $ydir] or
                $grid[$x][$maxy + $ydir]) {
              $canexpand = 0;
            }
          }
          if ($canexpand) {
            print "y";
            if ($ydir > 0) {
              $maxy += $ydir;
            } else {
              $miny += $ydir;
            }
            for $x ($minx .. $maxx) {
              $grid[$x][$miny] = $cellcount;
              $grid[$x][$maxy] = $cellcount;
              $gridcellcount++;
            }
          } else {
            print "0";
          }
        }
      }
      print "\n";
    };
    # Try to expand...
    $trytoexpand->(1, 0); # to the east
    $trytoexpand->(-1,0); # to the west
    $trytoexpand->(0,-1); # to the north
    $trytoexpand->(0, 1); # to the south
    # And now save the cell:
    $cell[$cellcount - 1] =
      +{ minx => $minx,
         miny => $miny,
         maxx => $maxx,
         maxy => $maxy,
         join => +{ map { $_ => ((60 > int rand 100) ? "open" : "wall") } qw(n s e w) },
         num  => $cellcount,
         #door => +{ (map { $colpos[$minx] + 1 + int rand($colpos[$maxx + 1] - $colpos[$minx] - 2) } qw(n s)),
         #           (map { $rowpos[$miny] + 1 + int rand($rowpos[$maxy + 1] - $rowpos[$miny] - 2) } qw(e w)) },
       };
    print "Used $gridcellcount of $cellmax grid cells (" .
      (sprintf("%0.1f", ($gridcellcount * 100 / $cellmax))) . '%)' . "\n";
    #print "Press Enter to show map...\n";
    #<STDIN>;
    #showmap();
  }
}

print "Placed $cellcount cells.\n";
showmap();


sub showmap {
  print color "reset";
  print "\n**********************************************\n\n";
  @map = ();
  for $cell (1 .. $cellcount) {
    my $c = $cell[$cell - 1];
    my $minx = $colpos[$$c{minx}];
    my $maxx = $colpos[$$c{maxx} + 1] - 1;
    my $miny = $rowpos[$$c{miny}];
    my $maxy = $rowpos[$$c{maxy} + 1] - 1;
    print "  cell $$c{num} [$$c{minx},$$c{miny},$$c{maxx},$$c{maxy}] => ($minx,$miny,$maxx,$maxy)\n";
    my $gridx = 0;
    for $x ($minx .. $maxx) {
      while ($colpos[$gridx + 1] <= $x) {
        $gridx++;
      }
      my $gridy = 0;
      for $y ($miny .. $maxy) {
        while ($rowpos[$gridy + 1] <= $y) {
          $gridy++;
        }
        $map[$x][$y] =
          +{ char => (#(($y == $miny and $x == $$c{door}{n}) ||
                      # ($y == $maxy and $x == $$c{door}{s}) ||
                      # ($x == $minx and $y == $$c{door}{w}) ||
                      # ($x == $maxx and $y == $$c{door}{e})) ? "+" :
                      (($y == $miny) and not ($gridy > 0 and $$c{join}{n} eq "open"
                                              and $grid[$gridx][$gridy - 1]
                                              and $cell[$grid[$gridx][$gridy - 1] - 1]{join}{s} eq "open"
                                              and $x > $colpos[$cell[$grid[$gridx][$gridy - 1] - 1]{minx}]
                                              and $x < $colpos[$cell[$grid[$gridx][$gridy - 1] - 1]{maxx}]
                                             )) ? "-" :
                      (($y == $maxy) and not ($gridy < $rowcount and $$c{join}{s} eq "open"
                                              and $grid[$gridx][$gridy + 1]
                                              and $cell[$grid[$gridx][$gridy + 1] - 1]{join}{n} eq "open"
                                              and $x > $colpos[$cell[$grid[$gridx][$gridy + 1] - 1]{minx}]
                                              and $x < $colpos[$cell[$grid[$gridx][$gridy + 1] - 1]{maxx}]
                                             )) ? "-" :
                      (($x == $minx) and not ($gridx > 0 and $$c{join}{w} eq "open"
                                              and $grid[$gridx - 1][$gridy]
                                              and $cell[$grid[$gridx - 1][$gridy] - 1]{join}{e} eq "open"
                                              and $y > $rowpos[$cell[$grid[$gridx - 1][$gridy] - 1]{miny}]
                                              and $y < $rowpos[$cell[$grid[$gridx - 1][$gridy] - 1]{maxy}]
                                             )) ? "|" :
                      (($x == $maxx) and not ($gridx < $colcount and $$c{join}{e} eq "open"
                                              and $grid[$gridx + 1][$gridy]
                                              and $cell[$grid[$gridx + 1][$gridy] - 1]{join}{w} eq "open"
                                              and $y > $rowpos[$cell[$grid[$gridx + 1][$gridy] - 1]{miny}]
                                              and $y < $rowpos[$cell[$grid[$gridx + 1][$gridy] - 1]{maxy}]
                                             )) ? "|" :
                      '.'#($$c{num} % 10)
                     ),
           };
      }
    }
  }

  # Now add in some corridors...
  my @visited;
  for my $cnum (1 .. $cellcount) {
    my $c    = $cell[$cnum - 1];
    my $minx = $colpos[$$c{minx}];
    my $maxx = $colpos[$$c{maxx} + 1] - 1;
    my $miny = $rowpos[$$c{miny}];
    my $maxy = $rowpos[$$c{maxy} + 1] - 1;
    my $x    = $minx + 1 + int rand($maxx - $minx - 2);
    my $y    = $miny + 1 + int rand($maxy - $miny - 2);
    my @dir = ([-1, 0], [1, 0], [0, -1], [0, 1]); # gridbug path
    my $dir = $dir[int rand @dir];
    $visited[$x][$y] = $cnum;
    my $turncount = 0;
    while ($x >= $minx and $x <= $maxx and $y >= $miny and $y <= $maxy) {
      $visited[$x][$y] ||= $cnum;
      $map[$x][$y]{fg} = 'blue'; # For testing
      if ($map[$x][$y]{char} =~ /[-|]/) {
        $map[$x][$y]{char} = '+';
        $map[$x][$y]{fg} = 'yellow';
      }
      $x += $$dir[0];
      $y += $$dir[1];
    }
    $visited[$x][$y] ||= $cnum;
    $map[$x][$y]{fg} = 'cyan'; # For testing
    $map[$x][$y]{char} = '#' if (($map[$x][$y]{char} || ' ') eq ' ');
    if ($map[$x][$y]{char} =~ /[-|]/) {
      $map[$x][$y]{char} = '.';
      $map[$x][$y]{fg} = 'yellow';
    }
    $x += $$dir[0];
    $y += $$dir[1];
    while ($x >= 0 and $x < $COLNO and $y >= 0 and $y < $ROWNO and
           not $visited[$x][$y]) {
      $visited[$x][$y] = $cnum;
      if (($map[$x][$y]{char} || ' ') eq ' ') {
        $map[$x][$y]{fg} = 'green'; # For testing
        $map[$x][$y]{char} = '#';
        my $origdir = $dir;
        if ($turncount == 0 and not int rand 5) {
          # Turn a right angle
          while (($$dir[0] ==      $$origdir[0] and $$dir[1] ==      $$origdir[1]) or
                 ($$dir[0] == -1 * $$origdir[0] and $$dir[1] == -1 * $$origdir[1])) {
            $dir = $dir[int rand @dir];
          }
          $turncount++;
        } else {
          my $nextx = $x + $$dir[0];
          my $nexty = $y + $$dir[1];
          # Try not to run end-on into a wall:
          if ((($$dir[0] and ($map[$nextx][$nexty]{char} eq '-')) or
               ($$dir[1] and ($map[$nextx][$nexty]{char} eq '|')))) {
            if ($turncount < 6) {
              # Turn a right angle
              my $olddir = $dir;
              while (($$dir[0] ==      $$olddir[0]  and $$dir[1] ==      $$olddir[1]) or
                     ($$dir[0] ==      $$origdir[0] and $$dir[1] ==      $$origdir[1]) or
                     ($$dir[0] == -1 * $$origdir[0] and $$dir[1] == -1 * $$origdir[1])) {
                $dir = $dir[int rand @dir];
              }
              $turncount++;
            } else {
              # Give up.
              $map[$nextx][$nexty]{fg} = 'magenta';
              $visited[$nextx][$nexty] = 1;
            }
          }
        }
      } elsif ($map[$x][$y]{char} =~ /[-|]/) {
        $map[$x][$y]{fg} = 'yellow';
        $map[$x][$y]{char} = '.';
      }
      $x = $x + $$dir[0];
      $y = $y + $$dir[1];
      if ($map[$x][$y]{char} =~ /[0-9.]/) {
        # Finish condition.
        $map[$x][$y]{fg} = 'red'; # for testing
        $visited[$x][$y] = 1; # this stops the loop
      }
    }
  }

  for $y (0 .. $ROWNO - 1) {
    for $x (0 .. $COLNO - 1) {
      my $tile = $map[$x][$y] || +{ char => ' ' };
      $$tile{char} ||= 'X';
      $$tile{fg}   ||= "white";
      $$tile{bg}   ||= "on_black";
      print color $$tile{bg};
      print color $$tile{fg};
      print $$tile{char};
    }
    print color "reset";
    print "!\n";
  }
}
