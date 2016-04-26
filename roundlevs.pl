#!/usr/bin/perl

use utf8;
use open ':encoding(UTF-8)';
use open ":std";

my $debug        = 0;
my $usecolor     = 1;
my $COLNO        = 79;#90;#79;
my $ROWNO        = 35;#20;
my $floorchar    = '·';
my $aspect       = 3/5;

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

print qq[ROWNO: $ROWNO; COLNO: $COLNO\n];

showmap($map);
#appendhtml($map);
exit 0; # subroutines follow

sub generate {
  my $cx = int(($COLNO - 1) / 2);
  my $cy = int(($ROWNO - 1) / 2);
  my $radius = (($cx * $aspect) > $cy) ? ($cy - 1) : (int($cx * $aspect) - 1);
  print "center: ($cx, $cy); radius: $radius\n";
  my $map;
  for my $x (0 .. $COLNO) {
    for my $y (0 .. $ROWNO) {
      my $xdist = int(abs($x - $cx) * $aspect);
      my $ydist = abs($y - $cy);
      my $dist = sqrt(($xdist * $xdist) + ($ydist * $ydist));
      if ($dist >= $radius) {
        $$map[$x][$y] = +{ type => "STONE",
                           bg   => "on_black",
                           fg   => "white",
                           char => " ",
                         };
      } else {
        $$map[$x][$y] = +{ type => "ROOM",
                           bg   => "on_black",
                           fg   => "white",
                           char => $floorchar,
                         };
      }
    }
  }
  return fixupwalls($map);
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
  return $map;
}

sub appendhtml {
  my ($map) = @_;
  use HTML::Entities;
  open HTML, ">>", "round-levels.xml";
  print HTML qq[<div class="leveltitle">Round Level:</div>
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


