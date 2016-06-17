#!/usr/bin/perl

use strict;
use Term::ANSIColor;
use Carp;

my %cmdarg = @ARGV;

my ($ROWNO, $COLNO) = (($cmdarg{ROWNO} || 21), ($cmdarg{COLNO} || 79));
my $roomcount = 0;
my $domonsters = 0;
my $pillarprob = $cmdarg{pillarprob} || 12;
my (@carvepoint, @room);

# TODO list:
# 1. The pillar placement probably ought to check that it's possible
#    to go around the pillar, and that it does not block any doors.
# 2. Parallel walls look ugly due to unnecessary cross connections.

my $corr  = +{ t => 'CORR',
               b => 'on_black',
               f => 'white',
               c => '#',
             };
my $ecorr = $corr;
  #+{ t => 'CORR',
  #   b => 'on_black',
  #   f => 'cyan',
  #   c => '#',
  # };
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
#my $northexit  = +{ c => 'N',
#               b => 'on_black',
#               f => 'yellow',
#               t => 'DOOR' };
#my $southexit  = +{ c => 'S',
#               b => 'on_black',
#               f => 'yellow',
#               t => 'DOOR' };
#my $eastexit  = +{ c => 'E',
#               b => 'on_black',
#               f => 'yellow',
#               t => 'DOOR' };
#my $westexit  = +{ c => 'W',
#               b => 'on_black',
#               f => 'yellow',
#               t => 'DOOR' };

my %wdir = ( E => +{ bit => 1, dx =>  1, dy =>  0, clockwise => 'S', },
             N => +{ bit => 2, dx =>  0, dy => -1, clockwise => 'E', },
             W => +{ bit => 4, dx => -1, dy =>  0, clockwise => 'N', },
             S => +{ bit => 8, dx =>  0, dy =>  1, clockwise => 'W', },
           );
my @wallglyph = qw/! ─ │ └ ─ ─ ┘ ┴ │ ┌ │ ├ ┐ ┬ ┤ ┼/;
$wallglyph[0] = '-';


my @map = (map {
  [ map { $stone } 0 .. $ROWNO ],
} 0 .. $COLNO);



my @carvemethod =
  (
   +{ name => 'onespot',
      type => 'corridor',
      make => sub {
        my ($ox, $oy, $odx, $ody, $parent) = @_;
        return carveonespot($ox, $oy, $odx, $ody, $parent,
                            (20 > int rand 100) ? $scorr : $corr);
      },
    },
   +{ name => 'spiral',
      type => 'corridor',
      make => sub {
        return carvespiral(@_);
      },
    },
   +{ name => 'basic_short_corridor',
      type => 'corridor',
      make => sub {
        my ($ox, $oy, $odx, $ody, $parent) = @_;
        return carvebasiccorridor($ox, $oy, $odx, $ody, $parent, $corr);
      },
    },
   +{ name => 'secret_corridor',
      type => 'corridor',
      make => sub {
        my ($ox, $oy, $odx, $ody, $parent) = @_;
        return carvebasiccorridor($ox, $oy, $odx, $ody, $parent, $scorr, 1 + int rand rand 2);
      },
    },
   +{ name => 'marketplace',
      type => 'room',
      make => sub {
        return carvemarketplace(@_);
      },
    },
   +{ name => 'tee',
      type => 'room',
      make => sub {
        return carvetee(@_);
      },
    },
   +{ name => 'Y',
      type => 'room',
      make => sub {
        return carveyroom(@_);
      },
    },
   +{ name => 'rhombus',
      type => 'room',
      make => sub {
        return carverhombus(@_);
      },
    },
   +{ name => 'octagon',
      type => 'room',
      make => sub {
        return carveoctagon(@_);
      },
    },
   (+{
     name => 'rectangle',
     type => 'room',
     make => sub {
       return carverectangle(@_);
     },
    }) x 2,
  );

my %count = map { $_ => 0 } qw(marketplace spiral);
#use Data::Dumper; print Dumper(+{ cmarray => \@carvemethod });
my $x  = 10 + int rand($COLNO - 20);
my $y  =  3 + int rand($ROWNO - 6);
my ($dx, $dy) = choosedir();
recursivecarve($x, $y, $dx, $dy, undef);
recursivecarve($x - $dx, $y - $dy, 0 - $dx, 0 - $dy, undef);

#$map[$x][$y] = $map[$x - $dx][$y - $dy] = $greenfloor; # for debug purposes

#showmap();
#print "\n";
#print color "green";
#print "--------------------------------------------------------------------";
#print color "reset";
#print "\n";

my $iota;
my $needswork = 1;
while ($needswork) {
  die "iota" if $iota++ > 1000;
  my $delta;
  while (@carvepoint) {
    die "delta" if $delta++ > 10000;
    my $e = shift @carvepoint;
    recursivecarve(@$e);
  }
  showmap();
  $needswork = 0;
  # But if there's a *huge* rectangle still unused, we can reseed in
  # the middle of it and go some more...
  my $maxyoff = int($ROWNO / 4);
  for my $yoff (1 .. $maxyoff) {
    if (rectisempty(1,$yoff,int($COLNO/5),$ROWNO+$yoff-$maxyoff-1)) {
      #print color "on_red"; print "NEEDS WORK (WEST)"; print color "reset"; print "\n";
      my $x = 0;
      my $y = int(($ROWNO + $yoff - ($maxyoff/2)) / 2);
      my $kappa;
      while (($map[$x][$y]{t} eq 'STONE') and ($x + 2 < $COLNO)) {
        die "kappa" if $kappa++ > 1000;
        $x++;
      }
      recursivecarve($x, $y, -1, 0, undef);
      recursivecarve($x, $y, 0, -1, undef);
      recursivecarve($x, $y, 0,  1, undef);
      #$map[$x][$y] = $greenfloor;
      $needswork++;
    }
    if (rectisempty(int($COLNO * 4 / 5), $yoff, $COLNO - 1, $ROWNO+$yoff-$maxyoff-1)) {
      #print color "on_red"; print "NEEDS WORK (EAST)"; print color "reset"; print "\n";
      my $x = $COLNO - 1;
      my $y = int(($ROWNO + $yoff - ($maxyoff/2)) / 2);
      my $lambda;
      while (($map[$x][$y]{t} eq 'STONE') and ($x > 2)) {
        die "lambda" if $lambda++ > 1000;
        $x--;
      }
      recursivecarve($x, $y, 1,  0, undef);
      recursivecarve($x, $y, 0, -1, undef);
      recursivecarve($x, $y, 0,  1, undef);
      #$map[$x][$y] = $greenfloor;
      $needswork++;
    }
  }
}
# Some rooms might should have pillars...
my $rno = 0;
for my $r (@room) {
  $rno++;
  if (($$r{type} eq 'room') and ($pillarprob > int rand 100)) {
    my $tries = 0;
    my ($cx, $cy) = (0, 0);
    while ((($cx == 0) or
            ($map[$cx][$cy]{r} ne $rno) or
            ($map[$cx][$cy]{t} ne 'ROOM')) and
           ($tries++ < 1000)) {
      $cx = 1 + int rand ($COLNO - 2);
      $cy = 1 + int rand ($ROWNO - 2);
    }
    for my $x (($cx - 1) .. ($cx + 1)) {
      for my $y (($cy - 1) .. ($cy + 1)) {
        if ($map[$x][$y]{t} eq 'ROOM') {
          $map[$x][$y] = $stone;
        } elsif ($map[$x][$y]{t} eq 'CORR') {
          $map[$x][$y] = $scorr;
        } elsif ($map[$x][$y]{t} eq 'DOOR') {
          $map[$x][$y] = $sdoor;
        }
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
      $map[$x][$y] = +{ b => 'on_black',
                        t => 'STAIR',
                        c => '>',
                        f => 'red',
                      };
    } else {
      $upstair = [$x, $y];
      $map[$x][$y] = +{ b => 'on_black',
                        t => 'STAIR',
                        c => '<',
                        f => 'red',
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
my $rno = 0;
for my $r (@room) {
  my $tries = 0;
  $rno++;
  if ($$r{type} eq 'room') {
    my $f = $randfeature[int rand @randfeature];
    if ($$f{prob} > rand 100) {
      my $multi = 1 + int rand rand $$f{count};
      my $placed = 0;
      while (($tries++ < 1000) and $placed < $multi) {
        my $x = int rand $COLNO;
        my $y = int rand $ROWNO;
        my $tile = $map[$x][$y];
        if (($$tile{r} == $rno) and
            ($$tile{t} == 'ROOM') and
            ((orthogonalfloorcount($x,$y) >= int((1000 - $tries) / 200))
             or not $$f{center}) and
            ((solidneighborcount($x,$y,0,0,0) >= int((1000 - $tries) / 333))
             or not $$f{onwall})
           ) {
          $map[$x][$y] = +{ %$tile,
                            %{$$f{tile}},
                          };
          if ($$f{monst}) {
            my $m = $monster[int rand @monster];
            my $c = $$m{color}[int rand @{$$m{color}}];
            $map[$x][$y] = +{ %$tile,
                              f => $c || 'cyan',
                              c => $$m{mlet} || 'I',
                            };
          }
          $placed++;
        }
      }
    }
  }
}
showmap();

sub rectisempty {
  my ($minx, $miny, $maxx, $maxy) = @_;
  my ($x, $y);
  #print "Checking for empty rectangle ($minx, $miny, $maxx, $maxy)...";
  for $x ($minx .. $maxx) {
    for $y ($miny .. $maxy) {
      if (($map[$x][$y]{t} || 'STONE') ne 'STONE') {
        #print "Not empty. ($x, $y) is $map[$x][$y]{t}\n";
        return;
      }
    }
  }
  #print color "green";
  #print "EMPTY";
  #print color "reset";
  #print "\n";
  return "empty";
}

sub choosedir {
  my ($xdir, $ydir) = (0, 0);
  my $epsilon;
  while (($xdir == 0) and ($ydir == 0)) {
    die "epsilon" if $epsilon++ > 10000;
    $xdir = (int rand 3) - 1;
    $ydir = (int rand 3) - 1;
  }
  return ($xdir, $ydir);
}

sub recursivecarve {
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  if ($ox < 0 or $ox > $COLNO) {
    #warn "recursivecarve: invalid x: $ox ($ox, $oy, $dx, $dy, $parent)\n";
    return;
  }
  if ($oy < 0 or $oy > $ROWNO) {
    #warn "recursivecarve: invalid y: $oy ($ox, $oy, $dx, $dy, $parent)\n";
    return;
  }
  my $tries = 0;
  my $cx = $ox + $dx;
  my $cy = $oy + $dy;
  my $roomno = undef;
  my $zeta;
  while ($tries++ < 55 and not defined $roomno) {
    die "zeta" if $zeta++ > 1000; # impossible
    my $carvemethod = $carvemethod[int rand @carvemethod];
    #use Data::Dumper; print Dumper(+{ carvemethod => $carvemethod });
    croak "Illegal direction ($dx,$dy)" if ($dx == 0 and $dy == 0);
    $roomno = $$carvemethod{make}->($cx, $cy, $dx, $dy, $parent);
  }
  if ($roomno) {
    # We have successfully carved a room.
    # Make the entrance:
    if ($ox > 0 and $oy > 0 and $ox < $COLNO and $oy < $ROWNO) {
      if ($dx and $dy) {
        $map[$ox][$oy] = $ecorr;
        $map[$cx][$cy] = $ecorr;
        if (50 > int rand 100) {
          $map[$cx][$oy] = $ecorr;
        } else {
          $map[$ox][$cy] = $ecorr;
        }
        if (50 > int rand 100) {
          $map[$ox][$oy - $dy] = $ecorr;
        } else {
          $map[$ox - $dx][$oy] = $ecorr;
        }
        if (50 > int rand 100) {
          $map[$cx][$cy + $dy] = $ecorr;
        } else {
          $map[$cx + $dx][$cy] = $ecorr;
        }
      } else {
        if ($room[$roomno]{type} eq 'corridor') {
          $map[$cx][$cy] = ($map[$cx][$cy]{t} eq 'WALL') ? $sdoor : $scorr;
        } else {
          $map[$cx][$cy] = (20 > int rand 100) ? $sdoor : $door;
        }
        $map[$ox][$oy] = #($map[$ox][$oy]{t} eq 'WALL') ? $sdoor : $ecorr;
          ($room[$roomno]{type} eq 'corridor') ? $ecorr : roomfloor($roomno)
          #+{ t => 'ROOM',
          #   b => 'on_black',
          #   f => 'cyan',
          #   c => '.',
          # }
            unless $map[$ox][$oy]{t} eq 'CORR';
      }
    }
    #showmap();
    #<STDIN>;
    # And now recursion...
    if ($roomno) {
      my @e = randomorder(@{$room[$roomno]{exit}});
      if (50 > int rand 100) {
        # Try to carve further from here now:
        if (@e) {
          my $e = shift @e;
          push @carvepoint, $_ for @e;
          return recursivecarve(@$e);
        }
      } else {
        push @carvepoint, $_ for @e;
        if (10 > int rand 100) {
          @carvepoint = randomorder(@carvepoint);
        }
        if (@carvepoint) {
          my $e = shift @carvepoint;
          recursivecarve(@$e);
        }
        if (@carvepoint) {
          my $e = shift @carvepoint;
          recursivecarve(@$e);
        }
      }
    }
  }
}

sub showmap {
  print "\n\n";
  for $y (0 .. $ROWNO) {
    for $x (0 .. $COLNO) {
      my $m = $map[$x][$y];
      print color $$m{b};
      print color $$m{f};
      print $$m{c};
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

sub carveonespot {
  my ($ox, $oy, $odx, $ody, $parent, $tile) = @_;
  $tile ||= $corr;
  my ($x, $y) = ($ox + $odx, $oy + $ody);
  if ($x > 0 and $x < $COLNO and $y > 0 and $y < $ROWNO and
      $map[$x][$y]{t} eq 'STONE') {
    $map[$x][$y] = $tile;
    $roomcount++;
    my $room = +{ type => 'corridor',
                  name => 'onespot',
                  entr => [$ox, $oy, $odx, $ody],
                  posn => [[$x, $y]],
                  exit => [[$x + $odx, $y + $ody, $odx, $ody, $roomcount], ],
                  parent => $parent,
                };
    $room[$roomcount] = $room;
    return $roomcount;
  }
}

sub carvespiral {
  my ($ox, $oy, $odx, $ody, $parent) = @_;
  my ($x, $y, $dx, $dy) = ($ox, $oy, $odx, $ody);
  if ($count{spiral} > 1) {
    push @carvepoint, [$ox, $oy, $odx, $ody, $parent];
    return;
  }
  my ($tillturn, $nexttillturn) = (1, 2);
  my @exit;
  my ($len, $turns) = (0, 0);
  my $doublethick = (65 > int rand 100) ? 1 : 0;
  $roomcount++;
  my $tile = (35 > int rand 100)
    ? +{ r => $roomcount, %$floor }
    : +{ r => $roomcount, %$corr  };
  while (($x > 0) and ($x < $COLNO) and
         ($y > 0) and ($y < $ROWNO) and
         ($map[$x][$y]{t} eq 'STONE')) {
    $map[$x][$y] = $tile;
      #+{ %$tile, c => ($nexttillturn % 10) };
    if ($doublethick) {
      my ($pdx, $pdy) = plusfortyfive($dx, $dy);
      my $px = $x + $pdx;
      my $py = $y + $pdy;
      if (($px > 1) and ($px + 1 < $COLNO) and
          ($py > 1) and ($py + 1 < $ROWNO) and
          ($map[$px][$py]{t} eq 'STONE')) {
        $map[$px][$py] = $tile;
      }
    }
    # Now advance to the next position:
    $x += $dx; $y += $dy;
    $tillturn--; $len++;
    if ($len == 3) { $count{spiral}++; }
    if ($tillturn <= 0) {
      my ($edx, $edy) = lessninety($dx, $dy);
      push @exit, [$x, $y, $dx, $dy, $roomcount];
      ($dx, $dy) = plusfortyfive($dx, $dy);
      $tillturn = $nexttillturn;
      $nexttillturn++;
      $turns++;
    }
  }
  if (($x > 0) and ($x < $COLNO) and
      ($y > 0) and ($y < $ROWNO)) {
    if ($map[$x][$y]{t} eq 'WALL') {
      $map[$x][$y] = $sdoor;
    }
  }
  my $room = +{ type => 'corridor',
                name => 'spiral',
                entr => [$ox, $oy, $odx, $ody],
                len  => $len,
                exit => [@exit],
              };
  $room[$roomcount] = $room;
  return $roomcount;
}

sub carvebasiccorridor {
  my ($ox, $oy, $odx, $ody, $parent, $corr, $length) = @_;
  if (($ox < 5 and $odx < 1) or
      ($ox > ($COLNO - 5) and $odx > -1) or
      ($oy < 3 and $ody < 1) or
      ($oy > ($ROWNO - 3) and $ody > -1)
     ) {
    return;
  }
  my ($x, $y, $dx, $dy) = ($ox, $oy, $odx, $ody);
  my ($minx, $miny, $maxx, $maxy) = ($x, $y, $x, $y);
  my $turncount = 0;
  my @proposed;
  $length ||= 3 + int rand 4;
  for my $p (1 .. $length) {
    if ($dx and (50 > int rand 100)) {
      $x += $dx;
    } elsif ($dy) {
      $y += $dy;
    } else {
      $x += $dx;
    }
    $proposed[$p] = [$x, $y];
    $minx = $x if $x < $minx;
    $miny = $y if $y < $miny;
    $maxx = $x if $x > $maxx;
    $maxy = $y if $y > $maxy;
    if ($turncount < 1 and (12 > int rand 100)) {
      my ($olddx, $olddy) = ($dx, $dy);
      my $alpha = 0;
      while ($dx == $olddx and $dy == $olddy) {
        ($dx, $dy) = choosedir();
        die "alpha" if $alpha++ > 1000;
      }
      $turncount++;
    }
  }
  my $cando = 1;
  for my $p (1 .. $length) {
    my ($x, $y) = @{$proposed[$p]};
    if (($x <= 1) or ($x + 1 >= $COLNO) or
        ($y <= 1) or ($y + 1 >= $COLNO) or
        $map[$x][$y]{t} ne 'STONE') {
      $cando = 0;
      return;
    }
  }
  my @exit = ([$x, $y, $dx, $dy, $roomcount]);
  my %hasexit;
  if ($cando) {
    for my $p (1 .. $length) {
      my ($x, $y) = @{$proposed[$p]};
      $map[$x][$y] = $corr;
      if ($x == $minx and $x > 5
          and not $hasexit{minx}++) {
        push @exit, [$x, $y, -1, 0, $roomcount];
      } elsif ($x == $maxx and $x + 5 < $COLNO
               and not $hasexit{maxx}++) {
        push @exit, [$x, $y, 1, 0, $roomcount];
      } elsif ($y == $miny and $y > 5
               and not $hasexit{miny}++) {
        push @exit, [$x, $y, 0, -1, $roomcount];
      } elsif ($y == $maxy and $y + 5 < $ROWNO
               and not $hasexit{maxy}++) {
        push @exit, [$x, $y, 0, 1, $roomcount];
      }
    }
  }
  $roomcount++;
  my $room = +{ type => 'corridor',
                name => 'basic_corridor',
                entr => [$ox, $oy, $odx, $ody],
                exit => [@exit],
                posn => [@proposed],
                parent => $parent,
              };
  $room[$roomcount] = $room;
  return $roomcount;
}

sub plusfortyfive {
  # This function is designed under the assumption that the only valid
  # coordinates are -1, 0, 1.  It rotates a rectangular-coordinate
  # vector with respect to the origin, one eighth turn (forty-five
  # degrees), counterclockwise.
  my ($x, $y) = @_;
  if (($x > 0) and ($y > 0)) {
    return (0, $y);
  } elsif (($x == 0) and ($y > 0)) {
    return (-1, $y);
  } elsif (($x < 0) and ($y > 0)) {
    return ($x, 0);
  } elsif (($x < 0) and ($y == 0)) {
    return ($x, -1);
  } elsif (($x < 0) and ($y < 0)) {
    return (0, $y);
  } elsif (($x == 0) and ($y < 0)) {
    return (1, $y);
  } elsif (($x > 0) and ($y < 0)) {
    return ($x, 0);
  } elsif (($x > 0) and ($y == 0)) {
    return ($x, 1);
  }
}

sub plusninety {
  # This function is designed under the assumption that the only valid
  # coordinates are -1, 0, 1.  It rotates a rectangular-coordinate
  # vector with respect to the origin, one quarter turn (ninety
  # degrees), counterclockwise.
  my ($x, $y) = @_;
  if ($y > 0) {
    return ($y, (0 - $x));
  } elsif (not $y) {
    return ($y, (0 - $x));
  } else {
    if ($x > 0) {
      return ((0 - $x), $y);
    } else {
      return ($y, (0 - $x))
    }
  }
}

sub lessninety {
  # This function is designed under the assumption that the only valid
  # coordinates are -1, 0, 1.  It rotates a rectangular-coordinate
  # vector, with respect to the origin, one quarter turn (ninety
  # degrees), clockwise.
  my ($x, $y) = @_;
  if ($x >= 0) {
    return ((0 - $y), $x);
  } else {
    if ($y > 0) {
      return ($x, (0 - $y));
    } elsif (not $y) {
      return ($y, $x);
    } else {
      return ((0 - $x), $y);
    }
  }
}

sub carverhombus {
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  my $size = 3 + int rand rand 15;
  my ($orthodx, $orthody);
  if ($dx and $dy) {
    push @carvepoint, [$ox, $oy, $dx, $dy, $parent];
    return;
  }
  if (50 < rand 100)  {
    ($orthodx, $orthody) = lessninety($dx, $dy);
  } else {
    ($orthodx, $orthody) = plusninety($dx, $dy);
  }
  my (@propose, @exit);
  my $conflict = 0;
  for my $row (1 .. $size) {
    my $cx = $ox + $dx * $row;
    my $cy = $oy + $dy * $row;
    my $offset = $row - int($size / 2);
    for my $o ($offset .. $offset + $size) {
      my $px = $cx + $orthodx * $o;
      my $py = $cy + $orthody * $o;
      push @propose, [$px, $py];
      if (($px <= 0) or ($px >= $COLNO) or
          ($py <= 0) or ($py >= $ROWNO) or
          $map[$px][$py]{t} ne 'STONE') {
        $conflict++;
      }
    }
    if ($row == $size) {
      my $ex = $cx + $orthodx * ($offset + int($size / 2));
      my $ey = $cy + $orthody * ($offset + int($size / 2));
      push @exit, [$ex, $ey, $dx, $dy, $parent];
    } elsif ($row == int($size / 2)) {
      # TODO: add side exits.
    }
  }
  if (not $conflict) {
    $roomcount++;
    for my $p (@propose) {
      my ($x, $y, $clr) = @$p;
      $map[$x][$y] = roomfloor($roomcount);
    }
    my $room = +{ type => 'room',
                  name => 'rhombus',
                  entr => [$ox, $oy, $dx, $dy],
                  #orth => [$orthodx, $orthody],
                  exit => [@exit],
                };
    $room[$roomcount] = $room;
    return $roomcount;
  }
}

sub carveyroom {
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  if ($dx and $dy) {
    if (50 > int rand 100) {
      $dx = 0;
    } else {
      $dy = 0;
    }
  }
  my $thickness = 2 + int rand 5;
  my $stemlen   = 1 + int rand 5;
  my $branchlen = 3 + int rand 8;
  my $diverge = 0;
  my ($dxa, $dya) = lessninety($dx, $dy);
  my ($dxb, $dyb) = plusninety($dx, $dy);
  my $conflict;
  my @propose; # Note: some tiles will get added twice.
  my @exit;
  for my $row (1 .. ($stemlen + $branchlen)) {
    if ($row > $stemlen) { $diverge++; }
    my $cx = $ox + $dx * $row;
    my $cy = $oy + $dy * $row;
    for my $offset ((0 - int($thickness / 2)) .. int($thickness / 2)) {
      # Branch A:
      my $xa = $cx + $dxa * ($offset + $diverge);
      my $ya = $cy + $dya * ($offset + $diverge);
      push @propose, [$xa, $ya];
      if (($xa <= 0) or ($xa >= $COLNO) or
          ($ya <= 0) or ($ya >= $ROWNO) or
          $map[$xa][$ya]{t} ne 'STONE') {
        $conflict++;
      }
      # Branch B:
      my $xb = $cx + $dxb * ($offset + $diverge);
      my $yb = $cy + $dyb * ($offset + $diverge);
      push @propose, [$xb, $yb];
      if (($xb <= 0) or ($xb >= $COLNO) or
          ($yb <= 0) or ($yb >= $ROWNO) or
          $map[$xb][$yb]{t} ne 'STONE') {
        $conflict++;
      }
    }
    if ($row == ($stemlen + $branchlen)) {
      push @exit, [$cx + $dxa * $diverge, $cy + $dya * $diverge, $dx, $dy, $roomcount];
      push @exit, [$cx + $dxb * $diverge, $cy + $dyb * $diverge, $dx, $dy, $roomcount];
    }
  }
  if (not $conflict) {
    $roomcount++;
    for my $p (@propose) {
      my ($x, $y, $clr) = @$p;
      $map[$x][$y] = roomfloor($roomcount);
    }
    my $room = +{ type => 'room',
                  name => 'Y',
                  entr => [$ox, $oy, $dx, $dy],
                  exit => [@exit],
                };
    $room[$roomcount] = $room;
    return $roomcount;
  }
}

sub carvemarketplace {
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  if (($count{marketplace} > 3) or (50 > int rand 100)) {
    push @carvepoint, [$ox, $oy, $dx, $dy, $parent];
    return;
  }
  my ($x, $y);
  my $radius = rand 5;
  my $xscale = 50;# + int rand 50;
  my $yscale = 30;# + int rand 30;
  my $beta;
  while ($radius > 2) {
    die "beta" if $beta++ > 1000;
    my ($cx, $cy) = ($ox, $oy);
    my $gamma;
    while (dist($cx, $cy, $ox, $oy, $xscale, $yscale) <= $radius) {
      die "gamma" if $gamma++ > 10000;
      $cx += $dx;
      $cy += $dy;
    }
    my $cando = 1;
    my $worthdoing = 0;
    my ($minx, $miny, $maxx, $maxy) = ($cx, $cy, $cx, $cy);
    for $x (1 .. $COLNO - 1) {
      for $y (1 .. $ROWNO - 1) {
        if (dist($cx, $cy, $x, $y, $xscale, $yscale) <= $radius) {
          if ($map[$x][$y]{t} ne 'STONE') {
            $cando = 0;
          } else {
            $worthdoing++;
          }
          $minx = $x if $x < $minx;
          $maxx = $x if $x > $maxx;
          $miny = $y if $y < $miny;
          $maxy = $y if $y > $maxy;
        }
      }
    }
    if ($cando and ($worthdoing > 4)) {
      my @exit;
      $roomcount++;
      for $x (1 .. $COLNO - 1) {
        for $y (1 .. $ROWNO - 1) {
          if (dist($cx, $cy, $x, $y, $xscale, $yscale) <= $radius) {
            $map[$x][$y] = roomfloor($roomcount);
            #} elsif (dist($cx, $cy, $x, $y, $xscale, $yscale) <= ($radius + 1) and
            #         $map[$x][$y]{t} eq 'STONE') {
            #  # TODO: try to work out exactly which kind of wall...
            #  $map[$x][$y] = +{ t => 'WALL',
            #                    b => 'on_black',
            #                    f => 'cyan',
            #                    c => '-',
            #                  };
          }
        }
      }
      $count{marketplace}++;
      push @exit, [$minx, $cy, -1, 0, $roomcount];
      push @exit, [$maxx, $cy,  1, 0, $roomcount];
      push @exit, [$cx, $miny, 0, -1, $roomcount];
      push @exit, [$cx, $maxy, 0,  1, $roomcount];
      my $room = +{ type => 'room',
                    name => 'marketplace',
                    minx => $minx,
                    miny => $miny,
                    maxx => $maxx,
                    maxy => $maxy,
                    cntr => [$cx, $cy],
                    size => $radius,
                    xsca => $xscale,
                    ysca => $yscale,
                    entr => [$ox, $oy, $dx, $dy],
                    exit => [@exit],
                    parent => $parent,
                  };
      $room[$roomcount] = $room;
      return $roomcount;
    }
    $radius--; # try smaller
  }
  return;
}

sub carvetee {
  my ($ox, $oy, $odx, $ody, $parent) = @_;
  #my @propose;
  my ($dx, $dy) = ($odx, $ody);
  my ($x, $y);
  if ($dx and $dy) {
    if (50 > int rand 100) {
      $dx = 0;
    } else {
      $dy = 0;
    }
  }
  # First, put together the base of the T:
  my ($bminx, $bminy, $bmaxx, $bmaxy) = ($ox, $oy, $ox, $oy);
  my $basewidth = 2 + int rand 4;
  my $baseheight = 2 + int rand 4;
  if ($odx) {
    $bmaxx += $basewidth * $odx;
  } else {
    $bminx -= int($basewidth / 2);
    $bmaxx += int($basewidth / 2);
  }
  if ($ody) {
    $bmaxy += $baseheight * $ody;
  } else {
    $bminy -= int($baseheight / 2);
    $bmaxy += int($baseheight / 2);
  }
  # Then the crosspiece:
  my ($tminx, $tminy, $tmaxx, $tmaxy) = ($bmaxx, $bmaxy, $bmaxx, $bmaxy);
  my $outdent = 2 + int rand 3;
  if ($dx) {
    if ($bmaxy < $bminy) { ($bminy, $bmaxy) = ($bmaxy, $bminy); }
    $tmaxx += $dx * (3 + int rand 2);
    $tminy  = $bminy - $outdent;
    $tmaxy  = $bmaxy + $outdent;
  } else {
    if ($bmaxx < $bminx) { ($bminx, $bmaxx) = ($bmaxx, $bminx); }
    $tmaxy += $dy * (3 + int rand 2);
    $tminx  = $bminx - $outdent;
    $tmaxx  = $bmaxx + $outdent;
  }
  # Make sure min and max are the right way 'round:
  if ($bmaxx < $bminx) { ($bminx, $bmaxx) = ($bmaxx, $bminx); }
  if ($bmaxy < $bminy) { ($bminy, $bmaxy) = ($bmaxy, $bminy); }
  if ($tmaxx < $tminx) { ($tminx, $tmaxx) = ($tmaxx, $tminx); }
  if ($tmaxy < $tminy) { ($tminy, $tmaxy) = ($tmaxy, $tminy); }
  # Can we actually place this tee?
  my $cando = 1;
  for $x ($bminx .. $bmaxx) {
    for $y ($bminy .. $bmaxy) {
      if ($x < 0 or $x > $COLNO or $y < 0 or $y > $ROWNO or
          $map[$x][$y]{t} ne 'STONE') {
        $cando = 0;
      }
    }
  }
  for $x ($tminx .. $tmaxx) {
    for $y ($tminy .. $tmaxy) {
      if ($x < 0 or $x > $COLNO or $y < 0 or $y > $ROWNO or
          $map[$x][$y]{t} ne 'STONE') {
        $cando = 0;
      }
    }
  }
  if ($cando) {
    $roomcount++;
    for $x ($tminx .. $tmaxx) {
      for $y ($tminy .. $tmaxy) {
        $map[$x][$y] = ($y == $tminy or $y == $tmaxy)
          ? $hwall : ($x == $tminx or $x == $tmaxx)
          ? $vwall : roomfloor($roomcount);
      }
    }
    for $x ($bminx .. $bmaxx) {
      for $y ($bminy .. $bmaxy) {
        $map[$x][$y] = (($x >= $tminx) and ($x <= $tmaxx) and
                        ($y >= $tminy) and ($y <= $tmaxy))
              ? roomfloor($roomcount) : ($y == $bminy or $y == $bmaxy)
              ? $hwall : ($x == $bminx or $x == $bmaxx)
              ? $vwall : roomfloor($roomcount);
      }
    }
    my @exit;
    if ($dx) {
      my $tmidx = $tminx + 1 + int rand($tmaxx - $tminx - 2);
      #$map[$tmidx][$tminy] = $northexit;
      #$map[$tmidx][$tmaxy] = $southexit;
      push @exit, [$tmidx, $tminy, 0, -1, $roomcount];
      push @exit, [$tmidx, $tmaxy, 0,  1, $roomcount];
    } else {
      my $tmidy = $tminy + 1 + int rand($tmaxy - $tminy - 2);
      #$map[$tminx][$tmidy] = $westexit;
      #$map[$tmaxx][$tmidy] = $eastexit;
      push @exit, [$tminx, $tmidy, -1, 0, $roomcount];
      push @exit, [$tmaxx, $tmidy,  1, 0, $roomcount];
    }
    my $room = +{ type => 'room',
                  name => 'tee',
                  #tdim => ($dx ? 'x' : 'y'),
                  minx => $bminx,
                  maxx => $bmaxx,
                  miny => $bminy,
                  maxy => $bmaxy,
                  tmnx => $tminx,
                  tmxx => $tmaxx,
                  tmny => $tminy,
                  tmxy => $tmaxy,
                  entr => [$ox, $oy, $odx, $ody],
                  exit => [@exit],
                };
    $room[$roomcount] = $room;
    return $roomcount;
  }
}

sub carveoctagon {
  #   xxx
  #  xxxxx
  # xxxxxxx
  # xxxxxxx
  # xxxxxxx
  #  xxxxx
  #   xxx
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  if ($dx and $dy) {
    # Don't want to code diagonal octagon tonight, try something else here later:
    push @carvepoint, [$ox, $oy, $dx, $dy, $parent];
    return;
  }
  for my $size (reverse (1 .. 2 + int rand rand 5)) {
    my (@propose, @exit, $row, $conflict);
    my @w = (($size .. (2 * $size)), ((2 * $size) x ($size - 2)), reverse ($size .. (2 * $size)));
    for my $w (@w) {
      $row++;
      if ($dx) {
        my $x = $ox + $row * $dx;
        for my $y (($oy - int($w / 2)) .. ($oy + int($w / 2))) {
          push @propose, [$x, $y];
          if (($x <= 0) or ($y <= 0) or
              ($x >= $COLNO) or ($y >= $ROWNO) or
              $map[$x][$y]{t} ne 'STONE') {
            $conflict++;
          }
        }
      } else {
        my $y = $oy + $row * $dy;
        for my $x (($ox - int($w / 2)) .. ($ox + int($w / 2))) {
          push @propose, [$x, $y];
          if (($x < 0) or ($y < 0) or
              ($x > $COLNO) or ($y > $ROWNO) or
              $map[$x][$y]{t} ne 'STONE') {
            $conflict++;
          }
        }
      }
    }
    if (not $conflict) {
      $roomcount++;
      my $half = int((scalar @w) / 2);
      if ($dx) {
        push @exit, [$ox + (scalar @w) * $dx, $oy, $dx, $dy, $roomcount];
        push @exit, [$ox + $half * $dx, $oy - $half, 0, -1, $roomcount];
        push @exit, [$ox + $half * $dx, $oy + $half, 0,  1, $roomcount];
      } else {
        push @exit, [$ox, $oy + (scalar @w) * $dy, $dx, $dy, $roomcount];
        push @exit, [$ox - $half, $oy + $half * $dy, -1, 0, $roomcount];
        push @exit, [$ox + $half, $oy * $half * $dy,  1, 0, $roomcount];
      }
      for my $p (@propose) {
        my ($x, $y) = @$p;
        $map[$x][$y] = roomfloor($roomcount);
      }
      my $room = +{ type => 'room',
                    name => 'octagon',
                    size => $size,
                    entr => [$ox, $oy, $dx, $dy],
                    exit => [@exit],
                  };
      $room[$roomcount] = $room;
      return $roomcount;
    }
  }
}

sub carverectangle {
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  #print "Trying rectangle";
  for my $try (1 .. 8) {
    my ($x, $y)       = ($ox, $oy);
    my ($minx, $miny) = ($x, $y);
    my $xsize = (3 + int rand 15);
    my $ysize = (3 + int rand 5);
    my $maxx = $x + ($dx * $xsize);
    my $maxy = $y + ($dy * $ysize);
    if ($dx == 0) {
      $minx -= int($xsize / 2);
      $maxx += int($xsize / 2);
    }
    if ($dy == 0) {
      $miny -= int($ysize / 2);
      $maxy += int($ysize / 2);
    }
    if ($minx > $maxx) { ($minx, $maxx) = ($maxx, $minx); }
    if ($miny > $maxy) { ($miny, $maxy) = ($maxy, $miny); }
    if ($minx < 0 or $maxx >= $COLNO or $miny < 0 or $maxy >= $ROWNO) {
      #print ".";
      next;
    }
    #print "($minx,$miny,$maxx, $maxy)";
    my $cando = 1;
    for $x ($minx .. $maxx) {
      for $y ($miny .. $maxy) {
        if ($map[$x][$y]{t} ne 'STONE') {
          $cando = 0;
        }
      }
    }
    if ($cando) {
      #print "  Yep.\n";
      $roomcount++;
      for $x ($minx .. $maxx) {
        for $y ($miny .. $maxy) {
          $map[$x][$y] =
            ($x == $minx or $y == $miny # or $x == $maxx or $y == $maxy
            )
              #? +{ t => 'WALL',
              #     b => 'on_black',
              #     f => 'white',
              #     c => (($y == $miny or $y == $maxy) ? '-' : '|'),
              #   }
              ? $hwall
              : roomfloor($roomcount);
        }
      }
      # Now assemble a list of exit points...
      my @exit;
      my $midx = $minx + 1 + int rand($maxx - $minx - 2);
      my $midy = $miny + 1 + int rand($maxy - $miny - 2);
      if ($dx == 0) {
        # Entrance is on the north or south edge
        if (50 > int rand 100) {
          # two potential exits, on the corners opposite the entrance
          my $exity = ($dy > 0) ? $maxy : $miny;
          push @exit, [$minx, $exity, -1, $dy, $roomcount];
          push @exit, [$maxx, $exity,  1, $dy, $roomcount];
        } else {
          # three potential exits, on the other sides
          push @exit, [$minx, $midy, -1, 0, $roomcount];
          push @exit, [$maxx, $midy,  1, 0, $roomcount];
          push @exit, [$midx, (($dy > 0) ? $maxy : $miny), 0, $dy, $roomcount];
        }
      } elsif ($dy == 0) {
        # Entrance is on the east or west edge
        if (50 > int rand 100) {
          # two potential exits, on the corners opposite the entrance
          my $exitx = ($dx > 0) ? $maxx : $minx;
          push @exit, [$exitx, $miny, $dx, -1, $roomcount];
          push @exit, [$exitx, $maxy, $dx, -1, $roomcount];
        } else {
          # three potential exits, on the other sides
          push @exit, [(($dx > 0) ? $maxx : $minx), $oy, $dx, $dy, $roomcount];
          push @exit, [$midx, $miny, 0, -1, $roomcount];
          push @exit, [$midx, $maxy, 0,  1, $roomcount];
        }
      } else {
        # Entrance is on a corner.
        if (50 > int rand 100) {
          # three potential exits on the other corners
          # opposite corner:
          push @exit, [(($dx > 0) ? $maxx : $minx), (($dy > 0) ? $maxy : $miny), $dx, $dy, $roomcount];
          # adjacent corners:
          push @exit, [$ox, (($dy > 0) ? $maxy : $miny), 0 - $dx, $dy, $roomcount];
          push @exit, [(($dx > 0) ? $maxx : $minx), $oy, $dx, 0 - $dy, $roomcount];
        } else {
          # two potential exits on the sides not adjacent to the entrance
          push @exit, [$midx, (($dy > 0) ? $maxy : $miny), 0, $dy, $roomcount];
          push @exit, [(($dx > 0) ? $maxx : $minx), $midy, $dx, 0, $roomcount];
        }
      }
      my $room = +{
                   type => 'room',
                   name => 'rectangle',
                   minx => $minx,
                   maxx => $maxx,
                   miny => $miny,
                   maxy => $maxy,
                   entr => [$ox, $oy, $dx, $dy],
                   exit => [@exit],
                   parent => $parent,
                  };
      $room[$roomcount] = $room;
      return $roomcount;
    } else {
      #print "x";
    }
  }
  #print " Nope.\n";
  return;
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
