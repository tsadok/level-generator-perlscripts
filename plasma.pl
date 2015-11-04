#!/usr/bin/perl

use utf8;
use open ':encoding(UTF-8)';
use open ":std";

my $debug        = 0;
my $usecolor     = 1;
my $COLNO        = 79;#90;#79;
my $ROWNO        = 20;#35;#20;
my $floorchar    = '·';
my $capmax       = 10000;
my $stonecutoff  = 1500 + int rand 3000; # TODO: decide this more intelligently.
my $maxfuzz      = 1000 + int rand 2000;
my $fuzzposprob  = 40 + int rand 20;

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

print qq[ROWNO: $ROWNO; COLNO: $COLNO
Stone cutoff at $stonecutoff (out of $capmax)
Fuzz up to $maxfuzz, ${fuzzposprob}% positive
];

showmap($map);
appendhtml($map);
exit 0; # subroutines follow


sub generate {
  my $plasma = [ map {
    [ map { 0 } 0 .. $ROWNO ]
  } 0 .. $COLNO];

  doplasma($plasma, 0, 0, $COLNO, $ROWNO);
  # Ensure that the edges of the map are solid:
  for my $x (0 .. $COLNO) {
    $$plasma[$x][0] = 0;
    $$plasma[$x][$ROWNO] = 0;
  }
  for my $y (0 .. $ROWNO) {
    $$plasma[0][$y] = 0;
    $$plasma[$COLNO][$y] = 0;
  }

  # TODO:  find the maximum $stonecutoff that makes a connected level,
  #        and choose a value between 1 and that for $stonecutoff.
  my $map = [ map {
    my $x = $_;
    [ map {
      my $y = $_;
      ($$plasma[$x][$y] < $stonecutoff) ?
        +{ type => 'STONE',
           bg   => 'on_black',
           fg   => 'yellow',
           char => ($debug ? (int($$plasma[$x][$y] / ($capmax / 10)) % 10) : ' '),
         } : +{
               type => 'ROOM',
               bg   => 'on_black',
               fg   => 'white',
               char => ($debug ? (int($$plasma[$x][$y] / ($capmax / 10)) % 10) : $floorchar),
              };
    } 0 .. $ROWNO ]
  } 0 .. $COLNO];

  # Decide stair positions:
  my $upx = int($COLNO / 10) + int rand($COLNO * 8 / 10);
  my $upy = int($ROWNO / 10) + int rand($ROWNO * 8 / 10);
  my ($dnx, $dny) = ($upx, $upy);
  while (($dnx == $upx) or ($dny == $upy)) {
    $dnx = int($COLNO / 4) + int rand($COLNO * 3 / 4);
    $dny = int($ROWNO / 4) + int rand($ROWNO * 3 / 4);
  }
  # Ensure connected paths:
  guaranteepath($map, $dnx, $dny, int($COLNO / 2), int($ROWNO / 2));
  guaranteepath($map, $upx, $upy, int($COLNO / 2), int($ROWNO / 2));

  # Place floor where the stairs will be
  $$map[$upx][$upy] = +{ type => 'ROOM',
                         bg   => 'on_red',
                         fg   => 'white',
                         char => $floorchar,
                       };
  $$map[$dnx][$dny] = +{ type => 'ROOM',
                         bg   => 'on_red',
                         fg   => 'white',
                         char => $floorchar,
                       };
  # Now fix up the walls with that in mind.
  fixupwalls($map);
  # Then actually place the stairs:
  $$map[$upx][$upy] = +{ type => 'STAIR',
                         bg   => 'on_red',
                         fg   => 'white',
                         char => '<',
                       };
  $$map[$dnx][$dny] = +{ type => 'STAIR',
                         bg   => 'on_red',
                         fg   => 'white',
                         char => '>',
                       };

  return $map;
}

sub guaranteepath {
  my ($map, $x, $y, $tx, $ty) = @_;
  while (($x ne $tx) or ($y ne $ty)) {
    my $xdist = abs($x - $tx);
    my $ydist = abs($y - $ty);
    if (($xdist * 100 / ($xdist + $ydist)) >= int rand 100) {
      $x += ($tx > $x) ? 1 : -1;
    } else {
      $y += ($ty > $y) ? 1 : -1;
    }
    $$map[$x][$y] = +{ type => 'ROOM',
                       bg   => 'on_black',
                       fg   => ($debug ? 'green' : 'white'),
                       char => $floorchar,
                     };
  }
}

sub fuzz {
  my $f = int(rand(2 * $maxfuzz + 1) / 2);
  if ($fuzzposprob >= int rand 100) {
    return $f;
  } else {
    return 0 - $f;
  }
}

sub doplasma {
  my ($p, $minx, $miny, $maxx, $maxy) = @_;
  if (($maxx <= $minx + 1) and ($maxy <= $miny + 1)) {
    return $p;
  }
  my $x = int(($minx + $maxx) / 2);
  my $y = int(($miny + $maxy) / 2);
  # Do the midpoints:
  if ($y > $miny) {
    $$p[$minx][$y] = cappedint(($$p[$minx][$miny] + $$p[$minx][$maxy]) / 2 + fuzz());
    $$p[$maxx][$y] = cappedint(($$p[$maxx][$miny] + $$p[$maxx][$maxy]) / 2 + fuzz());
  }
  if ($x > $minx) {
    $$p[$x][$miny] = cappedint(($$p[$minx][$miny] + $$p[$maxx][$miny]) / 2 + fuzz());
    $$p[$x][$maxy] = cappedint(($$p[$minx][$maxy] + $$p[$maxx][$maxy]) / 2 + fuzz());
  }
  if (($$p[$minx][$miny] <= 0) and
      ($$p[$minx][$maxy] <= 0) and
      ($$p[$maxx][$miny] <= 0) and
      ($$p[$maxx][$maxy] <= 0)) {
    # Special case:  all four corners are zero, make the middle 100:
    $$p[$x][$y] = $capmax;
  } elsif (($x > $minx) or ($y > $miny)) {
    $$p[$x][$y] = cappedint(($$p[$minx][$miny] + $$p[$minx][$maxy] +
                             $$p[$maxx][$miny] + $$p[$maxx][$maxy]) / 4 + fuzz());
  }
  if ($debug > 7) {
    print "($minx, $miny), ($maxx, $maxy): center ($x,$y)
        Corners: NW $$p[$minx][$miny], NE $$p[$maxx][$miny], SW $$p[$minx][$maxy], SE $$p[$maxx][$maxy]
        Edges:    W $$p[$minx][$y],  N $$p[$x][$miny],  E $$p[$maxx][$y],  S $$p[$x][$maxy]
        Center:  $$p[$x][$y]\n";
    if ($debug > 10) {
      <STDIN>;
    }
  }
  doplasma($p, $minx, $miny, $x, $y);
  doplasma($p, $x, $y, $maxx, $maxy);
  doplasma($p, $minx, $y, $x, $maxy);
  doplasma($p, $x, $miny, $maxx, $y);
  return $p;
}

sub cappedint {
  my ($n) = @_;
  if ($n < 0) {
    return 0;
  }
  if ($n > $capmax) {
    return $capmax;
  }
  return int $n;
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

sub fixupwalls {
  my ($map) = @_;
  for my $x (0 .. ($COLNO)) {
    for my $y (0 .. ($ROWNO)) {
      my $fg = $$map[$x][$y]{fg} || 'yellow';
      if ($$map[$x][$y]{type} =~ /STONE|WALL|UNDECIDED/) {
        if (countadjacent($map, $x, $y, 'ROOM')) {
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
  open HTML, ">>", "plasma-levels.xml";
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

