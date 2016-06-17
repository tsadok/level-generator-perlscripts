#!/usr/bin/perl

use utf8;
use open ':encoding(UTF-8)';
use open ":std";

my $debug        = 0;
my $usecolor     = 1;
my $COLNO        = 79;#90;#79;
my $ROWNO        = 35;#20;
my @floorchar    = ('·');
my @hillchar     = ('▲');
my @mountchar    = @hillchar;
my @treechar     = (('♠', '♣') x 3, '╕', '╒', '┬');
my @treecolor    = (("green") x 14, ("bold green") x 7, "yellow", "bold yellow", "bold black");
my $aspect       = 3/5;
my $treefreq     = rand rand 40;  $treefreq   = 0 if $treefreq   < (1  + int rand 5);
my $hillfreq     = rand rand 35;  $hillfreq   = 0 if $hillfreq   < (2  + int rand 7);
my $mountfreq    = rand rand 20;  $mountfreq  = 0 if $mountfreq  < (1  + int rand 4);
my $islefreq     = rand rand 40;  $islefreq   = 0 if $islefreq   < (1  + int rand 5);
my $desertfreq   = rand rand 120; $desertfreq = 0 if $desertfreq < (10 + int rand 50);
my $numlakes     = int rand 6;
my $numforests   = int rand 10;   $numforests = 0 if $numforests < (1 + int rand 5);
my $numranges    = (30 > int rand 100) ? (1 + int rand rand 3) : 0;
my $walkable     = qr/ROOM|TREE|HILL|POOL|STAIR/;
if ($numforests and (50 > int rand 100)) { $treefreq = 0; }
# Note that mountfreq and islefreq are conversion rates for hills.
# desertfreq is a conversion rate for regular floor.
print sprintf qq[D: $debug; C: $usecolor; Size: ($COLNO,$ROWNO)
Freq: %0.3f tree, %0.3f hill, %0.3f mtn; %0.3f isl; %0.3f dsrt;
      %0.3f L; %0.3f F; %0.3f M\n],
  $treefreq, $hillfreq, $mountfreq, $islefreq, $desertfreq,
  $numlakes, $numforests, $numranges;

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


#while (1) {
  my $map = generate();
  showmap($map);
#  print "Press Enter to continue...\n";
#  <STDIN>;
#  #appendhtml($map);
#}

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
      } elsif ($hillfreq > rand 100) {
        if ($mountfreq > rand 100) {
          $$map[$x][$y] = +{ type => "HILL",
                             bg   => "on_black",
                             fg   => "bold white",
                             char => $mountchar[rand @mountchar],
                           };
        } else {
          $$map[$x][$y] = +{ type => "HILL",
                             bg   => "on_black",
                             fg   => "yellow",
                             char => $hillchar[rand @hillchar],
                           };
        }
      } elsif ($treefreq > rand 100) {
        $$map[$x][$y] = +{ type => "TREE",
                           bg   => "on_black",
                           fg   => $treecolor[rand @treecolor],
                           char => $treechar[rand @treechar],
                         };
      } else {
        $$map[$x][$y] = +{ type => "ROOM",
                           bg   => "on_black",
                           fg   => (($desertfreq > rand 100) ? "yellow" : "white"),
                           char => $floorchar[rand @floorchar],
                         };
      }
    }
  }
  $map = fixupwalls($map);
  for (1 .. $numlakes) {
    placelake($map);
  }
  for (1 .. $numranges) {
    placemountrange($map);
  }
  for (1 .. $numforests) {
    placeforest($map, undef, undef, undef, undef, undef, 1 + rand int rand int rand 12);
  }
  return $map;
}

sub placeforest { # can also be used e.g. for lakes
  my ($map, $terrain, $prob, $doislands, $cx, $cy, $radius) = @_;
  $terrain ||= +{ type => "TREE",
                  bg   => "on_black",
                  fg   => \@treecolor,
                  char => \@treechar, };
  $prob    ||= 95 - int rand int rand 80;
  $cx      ||= 5 + rand ($COLNO - 10);
  $cy      ||= 3 + rand ($ROWNO - 6);
  $radius  ||= 1 + rand int rand ((($ROWNO > $COLNO) ? $COLNO : $ROWNO) / 4);
  my $minx = $cx - ($radius / $aspect);
  my $maxx = $cx + ($radius / $aspect);
  my $miny = $cy - $radius;
  my $maxy = $cy + $radius;
  for my $x ($minx .. $maxx) {
    for my $y ($miny .. $maxy) {
      if (($x > 0) and ($x < $COLNO) and ($y > 0) and ($y < $ROWNO) and
          ($prob > rand 100)) {
        my $xdist = abs($cx - $x) * $aspect;
        my $ydist = abs($cy - $y);
        my $dist = sqrt(($xdist * $xdist) + ($ydist * $ydist));
        if (($dist <= $radius) and not ($$map[$x][$y]{type} =~ /STONE|WALL|STAIR|POOL/)) {
          if (($$map[$x][$y]{type} ne "HILL") or
              (not $doislands) or
              ($islefreq * (($$map[$x][$y]{fg} eq "bold white") ? 1.5 : 1) <= int rand 100)) {
            $$map[$x][$y] = +{ %$terrain };
            for my $field (qw(fg bg char type)) {
              if (ref ($$map[$x][$y]{$field})) {
                $$map[$x][$y]{$field} = ${$$map[$x][$y]{$field}}[rand @{$$map[$x][$y]{$field}}];
              }}
          }
        }}
    }}
}

sub placemountrange { # can also be used e.g. for rivers.
  my ($map, $halfterrain, $fullterrain, $prob, $xone, $yone, $xtwo, $ytwo, $dx, $dy) = @_;
  warn "placemountrange();\n";
  $halfterrain ||= +{ type => "HILL",
                      bg   => "on_black",
                      fg   => "yellow",
                      char => \@hillchar, };
  $fullterrain ||= +{ type => "HILL",
                      bg   => "on_black",
                      fg   => "bold white",
                      char => \@mountchar, };
  my $hf  = ($hillfreq > 50) ? $hillfreq : (100 - $hillfreq);
  $hf     = rand $hf if $hf > 85;
  $prob ||= $hf;
  $xone ||= 2 + int rand ($COLNO / 2);
  $yone ||= ($ROWNO / 3) + rand (($ROWNO + 1) / 3);
  $xtwo ||= $xone + 1 + rand 5;
  $ytwo ||= $yone;
  $dx   ||= 1 + rand rand($xtwo - $xone);
  $dy   ||= (50 > rand 100) ? 1 : -1;
  my $maxsize = $ROWNO / 2;
  while (($xone > 0) and ($xone < $COLNO) and ($yone > 0) and ($yone < $COLNO) and
         ($xtwo > 0) and ($xtwo < $COLNO) and ($ytwo > 0) and ($ytwo < $COLNO) and
         (abs($dx) > 0) and (abs($dy) > 0) and
         ($maxsize-- > 0)) {
    for my $x ($xone .. $xtwo) {
      for my $y ($yone .. $ytwo) {
        if (($$map[$x][$y]{type} =~ /ROOM/) and ($prob > int rand 100)) {
          $$map[$x][$y] = +{ %{($prob > int rand 100) ? $fullterrain : $halfterrain} };
          for my $field (qw(fg bg char type)) {
            if (ref ($$map[$x][$y]{$field})) {
              $$map[$x][$y]{$field} = ${$$map[$x][$y]{$field}}[rand @{$$map[$x][$y]{$field}}];
            }}
        }
      }
    }
    $xone += $dx;
    $xtwo += $dx;
    $yone += $dy;
    $ytwo += $dy;
    $dx = ($dx / abs($dx)) * (1 + abs(($dx - 1) / 3) + rand(abs(($dx - 1)) * 4 / 3));
  }
  warn "  * exiting\n";
}

sub placelake {
  my ($map, $cx, $cy, $radius) = @_;
  placeforest($map, +{ type => "POOL",
                               bg   => "on_blue",
                               fg   => "bold cyan",
                               char => "}",
                             },
              100, "doislands", $cx, $cy, $radius);
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
      } elsif ($$map[$cx][$cy]{type} =~ $type) {
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
        if (countadjacent($map, $x, $y, $walkable)) {
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
      if ($$map[$x][$y]{type} =~ $walkable) {
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
      print color "reset" if $usecolor;
    }
    print "\n";
  }
  print "\n\n";
  if ($debug > 7) {
    <STDIN>;
  }
}


