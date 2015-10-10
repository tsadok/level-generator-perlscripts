#!/usr/bin/perl

use utf8;
use open ':encoding(UTF-8)';
use open ":std";

my $debug        = 7;
my $usecolor     = 1;
my $COLNO        = 79;#90;#79;
my $ROWNO        = 20;#35;#20;
my $iterations   = 100;
my $floorchar    = '·';
my @mold =
  (
   +{ char       => 'T', fg => 'green',  type     => 'TREE',
      seed       => 3,   maxage     => 99,
      minsameadj => 0,   maxsameadj => 6, samerep => 3,
      mintotadj  => 0,   maxothradj => 4, rndrep  => 1, },
   +{ char       => 'O', fg => 'white',   type    => 'ROOM',
      seed       => 6,   maxage     => 8,
      minsameadj => 1,   maxsameadj => 9, samerep => 4,
      mintotadj  => 3,   maxothradj => 8, rndrep  => 4,
    },
   +{ char       => 'x', fg => 'cyan',    type    => 'ROOM',
      seed       => 3,   maxage     => 12,
      minsameadj => 0,   maxsameadj => 4, samerep => 1,
      mintotadj  => 2,   maxothradj => 9, rndrep  => 45,
    },
   +{ char       => '+', fg => 'blue',    type    => 'ROOM',
      seed       => 3,   maxage     => 17,
      minsameadj => 0,   maxsameadj => 4, samerep => 1,
      mintotadj  => 2,   maxothradj => 9, rndrep  => 35,
    },
  );

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

  my $keepseeding = 1;
  my $tries = 0;
  while ($keepseeding and ($tries < 1000)) {
    $keepseeding = 0; $tries++;
    $tries = 0 if $tries < 0;
    for my $m (@mold) {
      if ($$m{seed}) {
        $keepseeding++;
        my $x = 3 + int rand ($COLNO - 6);
        my $y = 2 + int rand ($ROWNO - 4);
        if ($$map[$x][$y]{type} eq 'UNDECIDED' and
            (countadjacent($map, $x, $y, qr/UNDECIDED/) == 8)) {
          $$map[$x][$y] = +{ (%$m), age => int($$m{maxage} / 5), };
          my @n = map {
            my ($dx, $dy) = @$_;
            [$x + $dx, $y + $dy];
          } @neighbormatrix;
          @n = map {$$_[0]} sort { $$a[1] <=> $$b[1]} map { [$_ => int rand 1000] } @n;
          for my $ni (1 .. $$m{mintotadj}) {
            my ($nx, $ny) = @{$n[$ni - 1]};
            $$map[$nx][$ny] = +{ (%$m), age => 0, };
          }
          $$m{seed}--;
          $tries -= $keepseeding;
        }
      }
    }
  }
  if ($debug) {
    showmap($map);
    <STDIN>;
  }
  my @pos = map { [-1, -1] } 0 .. (($ROWNO + 1) * ($COLNO + 1));
  my $pi = 0;
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      $pos[$pi] = [$x, $y];
      $pi++;
    }}
  my $maxpos = $pi - 1;
  for my $pi (0 .. $maxpos) {
    my $opi = int rand $maxpos;
    ($pos[$pi], $pos[$opi]) = ($pos[$opi], $pos[$pi]);
  }
  for my $iter (1 .. $iterations) {
    showmap($map) if $debug;
    <STDIN> if $debug > 6;
    for my $pi (0 .. $maxpos) {
      my ($x, $y) = @{$pos[$pi]};
      if ($$map[$x][$y]{type} ne 'UNDECIDED') {
        $$map[$x][$y]{age}++;
        my $totadj  = countadjacent($map, $x, $y, qr/ROOM|CORR|TREE/);
        my $sameadj = countadjacent($map, $x, $y, qr/ROOM|CORR|TREE/, $$map[$x][$y]{char});
        if (($sameadj == $$map[$x][$y]{samerep}) or
            ($$map[$x][$y]{rndrep} >= int rand 100)) {
          my $npos = $neighbormatrix[rand @neighbormatrix];
          my ($dx, $dy) = @$npos;
          if ($$map[$x + $dx][$y + $dy]{type} eq 'UNDECIDED') {
            $$map[$x + $dx][$y + $dy] = +{ %{$$map[$x][$y]}, age => 0 };
          }
        }
        if (($$map[$x][$y]{age} > $$map[$x][$y]{maxage}) or
            ($sameadj < $$map[$x][$y]{minsameadj}) or
            ($sameadj > $$map[$x][$y]{maxsameadj}) or
            ($totadj  < $$map[$x][$y]{mintotadj})  or
            (($totadj - $sameadj) > $$map[$x][$y]{maxothradj})) {
          # It dies.
          $$map[$x][$y] = +{ type => 'UNDECIDED', char => ' ', fg => 'yellow', bg => 'on_black' };
        }
      }
    }
  }

  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      if (($x == 0) or ($x == $COLNO) or
          ($y == 0) or ($y == $ROWNO)) {
        $$map[$x][$y] = +{ type => 'STONE',
                           char => ' ',
                           fg   => 'yellow',
                           bg   => 'on_black',
                         };
      } elsif ($$map[$x][$y]{type} eq 'UNDECIDED') {
        my $adjfloor = countadjacent($map, $x, $y, qr/ROOM|CORR|TREE/);
        if (($adjfloor == 0) or ($adjfloor >= 7)) {
          $$map[$x][$y] = +{ type => 'STONE',
                             char => ' ',
                             fg   => 'yellow',
                             bg   => 'on_black',
                           };
        } elsif ($adjfloor <= 3) {
          $$map[$x][$y] = +{ type => 'CORR',
                             char => '#',
                             fg   => 'white',
                             bg   => 'on_black',
                           };
        } else {
          $$map[$x][$y] = +{ type => 'ROOM',
                             char => $floorchar,
                             fg   => 'red',
                             bg   => 'on_black',
                           };
        }
      } elsif ($$map[$x][$y]{type} ne 'UNDECIDED') {
        $$map[$x][$y] = +{ %{$$map[$x][$y]}, char => $floorchar };
      }
    }
  }

  fixupwalls($map);
  return $map;
}

sub countadjacent {
  my ($map, $x, $y, $typere, $char) = @_;
  my $count = 0;
  for my $cx (($x - 1) .. ($x + 1)) {
    for my $cy (($y - 1) .. ($y + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count.
      } elsif (($cx < 1) or ($cx >= $COLNO) or
               ($cy < 1) or ($cy >= $ROWNO)) {
        # Out of bounds, doesn't count
      } elsif ($$map[$cx][$cy]{type} =~ $typere) {
        if ((not $char) or ($char eq $$map[$cx][$cy]{char})) {
          $count++;
        }
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

