#!/usr/bin/perl

use strict;
use Term::ANSIColor;
use Carp;

my ($ROWNO, $COLNO) = (21, 79);
my $roomcount = 0;
my (@carvepoint, @room);

my $corr  = +{ t => 'CORR',
               b => 'on_black',
               f => 'white',
               c => '#',
             };
my $ecorr = $corr;#+{ t => 'CORR',
#               b => 'on_black',
#               f => 'cyan',
#               c => '#',
#             };
my $scorr = +{ t => 'CORR',
               b => 'on_black',
               f => 'blue',
               c => '#',
             };
my $floor = +{ t => 'ROOM',
               b => 'on_black',
               f => 'white',
               c => '.',
             };
my $redfloor = +{ t => 'ROOM',
               b => 'on_black',
               f => 'red',
               c => '.',
             };
my $bluefloor = +{ t => 'ROOM',
               b => 'on_black',
               f => 'blue',
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
   +{ name => 'basic_short_corridor',
      type => 'corridor',
      make => sub {
        my ($ox, $oy, $odx, $ody, $parent) = @_;
        return carvebasiccorridor($ox, $oy, $odx, $ody, $parent, $corr);
      },
    },
   +{ name => 'secret_short_corridor',
      type => 'corridor',
      make => sub {
        my ($ox, $oy, $odx, $ody, $parent) = @_;
        return carvebasiccorridor($ox, $oy, $odx, $ody, $parent, $scorr);
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
   (+{
     name => 'rectangle',
     type => 'room',
     make => sub {
       return carverectangle(@_);
     },
    }) x 2,
  );

#use Data::Dumper; print Dumper(+{ cmarray => \@carvemethod });
my $x  = 10 + int rand($COLNO - 20);
my $y  =  3 + int rand($ROWNO - 6);
my ($dx, $dy) = choosedir();
recursivecarve($x, $y, $dx, $dy, undef);
recursivecarve($x - $dx, $y - $dy, 0 - $dx, 0 - $dy, undef);
#showmap();
#print "\n";
#print color "green";
#print "--------------------------------------------------------------------";
#print color "reset";
#print "\n";

my $iota;
my $needswork = 1;
my $marketplacecount = 0;
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
  if (rectisempty(1,1,int($COLNO/5),$ROWNO-1)) {
    #print color "on_red"; print "NEEDS WORK (WEST)"; print color "reset"; print "\n";
    my $x = 0;
    my $y = int($ROWNO / 2);
    my $kappa;
    while (($map[$x][$y]{t} eq 'STONE') and ($x * 2 < $COLNO)) {
      die "kappa" if $kappa++ > 1000;
      $x++;
    }
    recursivecarve($x, $y, -1, 0, undef);
    $needswork++;
  }
  if (rectisempty(int($COLNO * 4 / 5), 1, $COLNO - 1, $ROWNO - 1)) {
    #print color "on_red"; print "NEEDS WORK (EAST)"; print color "reset"; print "\n";
    my $x = $COLNO - 1;
    my $y = int($ROWNO / 2);
    my $lambda;
    while (($map[$x][$y]{t} eq 'STONE') and ($x * 2 > $COLNO)) {
      die "lambda" if $lambda++ > 1000;
      $x--;
    }
    recursivecarve($x, $y, 1, 0, undef);
    $needswork++;
  }
}

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
          $map[$cx][$cy] = ($map[$cx][$cy]{t} eq 'WALL') ? $sdoor : $ecorr;
        } else {
          $map[$cx][$cy] = (20 > int rand 100) ? $sdoor : $door;
        }
        $map[$ox][$oy] = ($map[$ox][$oy]{t} eq 'WALL') ? $sdoor : $ecorr;
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

sub carvebasiccorridor {
  my ($ox, $oy, $odx, $ody, $parent, $corr) = @_;
  if (($ox < 5 and $odx < 1) or
      ($ox > ($COLNO - 5) and $odx > -1) or
      ($oy < 3 and $ody < 1) or
      ($oy > ($ROWNO - 3) and $ody > -1)
     ) {
    return;
  }
  my ($x, $y, $dx, $dy) = ($ox, $oy, $odx, $ody);
  my ($minx, $miny, $maxx, $maxy) = ($x, $y, $x, $y);
  my $length = 3 + int rand 4;
  my $turncount = 0;
  my @proposed;
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
    if ($x < 1 or $x >= $COLNO or $y < 1 or $y >= $COLNO
        or $map[$x][$y]{t} ne 'STONE') {
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

sub carvemarketplace {
  my ($ox, $oy, $dx, $dy, $parent) = @_;
  if ($marketplacecount > 3) { return; } # Don't put too many of these on one level.
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
            $map[$x][$y] = $floor;
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
      $marketplacecount++;
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
                    radi => $radius,
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
  my @proposed;
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
          ? $vwall : $floor;
      }
    }
    for $x ($bminx .. $bmaxx) {
      for $y ($bminy .. $bmaxy) {
        $map[$x][$y] = (($x >= $tminx) and ($x <= $tmaxx) and
                        ($y >= $tminy) and ($y <= $tmaxy))
              ? $floor : ($y == $bminy or $y == $bmaxy)
              ? $hwall : ($x == $bminx or $x == $bmaxx)
              ? $vwall : $floor;
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
                  tdim => ($dx ? 'x' : 'y'),
                  bmnx => $bminx,
                  bmxx => $bmaxx,
                  bmny => $bminy,
                  bmxy => $bmaxy,
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
    if ($minx < 0 or $maxx > $COLNO or $miny < 0 or $maxy > $ROWNO) {
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
            ($x == $minx or $x == $maxx or $y == $miny or $y == $maxy)
              ? +{ t => 'WALL',
                   b => 'on_black',
                   f => 'white',
                   c => (($y == $miny or $y == $maxy) ? '-' : '|'),
                 }
                : $floor;
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

