#!/usr/bin/perl

use Term::ANSIColor;

my %arg;
while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg =~ /^(rows|cols|delay)/) {
    my $k = $1;
    if ($arg =~ /(\d+)$/) {
      $arg{$k} = $1;
    } else {
      $arg{$k} = shift @ARGV;
    }
  } elsif ($arg =~ /^asmo/) {
    $arg{lair} = (rand(100) > 30) ? 'asmo2' : 'asmo1';
  } elsif ($arg =~ /^baal/) {
    $arg{lair} = 'baal';
  } elsif ($arg =~ /^gery/) {
    $arg{lair} = 'geryon';
  } elsif ($arg =~ /^disp/) {
    $arg{lair} = 'dis';
  } elsif ($arg =~ /showprogress/) {
    $arg{$arg} = 1;
  }
}
my $rows  = 22;
my $cols  = 80;
my $showprogress = $arg{showprogress};
sub delay {
  select undef, undef, undef, $arg{delay} if $arg{delay};
}

$|=1;

# Initialize the map to solid rock:
my @map = map {
  [ map {
    +{
      TERRAIN => 'UNDECIDED',
      GLYPH   => '?',
      COLOR   => 'magenta',
      BG      => 'on_black',
     }
  } 1 .. $rows ]
} 1 .. $cols;
my ($upx, $upy, $dnx, $dny) = (0, 0, 0, 0);
my ($xoffset, $yoffset)     = (0, 0); # offset for most important embedded content
my $size = $rows * $cols;
my $desiredlava = int((50 + rand rand 15) * $size / 100);
my $lavacount;

if ($showprogress) {
  print "Blank Map: \n"; showmap(); delay();
}

# ******************* Embed possible special components:

if ($arg{lair} eq 'geryon') {
  print "Geryon's Lair:\n";
  my @embed = parseembed('------------------------------? ',
                         '|???.????????| |?????.....???|?L',
                         '|??..????????---????.---.????|?L',
                         '--....?????????.?????| |?.???--?',
                         '?|???---???????.?????---??.???|?',
                         '.S???| |??????...?????.????.??|?',
                         '?|???---???????---?....?????.?|L',
                         '?|????..?????..| |...????????.--',
                         '--?????..??..??---??..??---?...|',
                         '|??---??...??????????...| |....|',
                         '|??| |???.???????????..?---??.--',
                         '--?---.??---?????????.????????|?',
                         '?|.??....| |???...??..??????---?',
                         'L|????..?---?...?..---??????| |L',
                         '?|?????.???.??.????| |??????---?',
                         '----???.???..---???---...?????|?',
                         '|  |??.???...| |????????...???S.',
                         '----?.????...---??????????..??--',
                         '?|...??---.???????????????.????|',
                         '?------| |----------------------',);
  #$embedsize = (scalar @embed) * (scalar @{$embed[0]});
  # We want to center it:
  $xoffset = int(($cols - scalar @{$embed[0]}) / 2);
  $yoffset = int(($rows - scalar @embed) / 2);
  print "Embedding lair at ($xoffset,$yoffset)\n";
  $desiredlava -= 100; # Mostly to account for the walls.
  my $dy = 0;
  for my $line (@embed) {
    my $dx = 0;
    for my $tile (@$line) {
      $map[$xoffset + $dx][$yoffset + $dy] = $tile;
      $dx++;
    }
    $dy++;
  }
  # The fill rules for inside an embed are different:
  # Instead of lava or rock, it can be lava or floor:
  for my $y (1 .. (scalar @embed) - 2) {
    for my $x (1 .. (scalar @{$embed[0]} - 2)) {
      my $newtile = (rand(100) > 60) ? lavatile() : floortile();
      maybefill($x + $xoffset, $y + $yoffset, 'UNDECIDED', $newtile);
      if ($map[$x + $xoffset][$y + $yoffset]{TERRAIN} eq 'LAVA') {
        $lavacount++;
      } else {
        $desiredlava-- if int rand(100) < int(50 + rand rand 15);
      }
    }
  }
  $upx = 2 + int rand ($xoffset - 4);
  $dnx = $cols - 2 - int rand ($xoffset - 4);
  $upy = 2 + int rand ($rows - 4);
  $dny = 2 + int rand ($rows - 4);
  if ($showprogress) {
    print "Embedded Geryon's Lair: \n"; showmap(); delay();
  }
} elsif ($arg{lair} eq 'asmo2') {
  print "Asmodeus' Lair (Version B):\n";
  print "TODO: Actually Design This Level\n";
} elsif ($arg{lair} eq 'asmo1') {
  print "Asmodeus' Lair (Version A):\n";
  # This is mostly based on his lair in 3.4.3, which frankly is not
  # one of the better levels in the game.  TODO:  At some point I
  # really should redesign this level entirely from scratch.
  my @embeda = parseembed('---------------------',
                          '|???........??|.????|',
                          '|??.....????..S...??|',
                          '|---+------------..?|',
                          '|?....|??...?...|-+--',
                          '|..---|....???.?|?.?.',
                          '|.?|?.S.........|.??L',
                          '|.?|?.|?........|....',
                          '|?.|..|??......?|-+--',
                          '|?.|..-----------?..|',
                          '|..S........??|?????|',
                          '---------------------');
  my @embedb = parseembed('?.LL?L.??LL..??LLL.L?..L?.L?',
                          '--------------------------?L',
                          '.??..??L???.?...???L???.L|.?',
                          '??.?..?.??.?.???..??.?.?.+..',
                          '..????.?..????????..L..?.|.L',
                          '--------------------------L?',
                          'L?..LL?LLLL..??L.LL..?.L??L?');
  #$embedsize = (scalar @embeda) * (scalar @{$embeda[0]})
  #              + (scalar @embedb) * (scalar @{$embedb[0]});
  $xoffset      = int(($cols - (scalar @{$embeda[0]}
                                + scalar @{$embedb[0]})) / 2);
  $xoffsetb     = $xoffset + scalar @{$embeda[0]};
  $yoffset      = int(($rows - scalar @embeda) / 2);
  $yoffsetb     = int(($rows + 1 - scalar @embedb) / 2);
  print "Embedding main lair at ($xoffset,$yoffset), wing at ($xoffsetb,$yoffsetb)\n";
  $desiredlava -= 100; # Mostly to account for the walls.
  my $dy = 0;
  for my $line (@embeda) {
    my $dx = 0;
    for my $tile (@$line) {
      $map[$xoffset + $dx][$yoffset + $dy] = $tile;
      $dx++;
    }
    $dy++;
  }
  $dy = 0;
  for my $line (@embedb) {
    my $dx = 0;
    for my $tile (@$line) {
      $map[$xoffsetb + $dx][$yoffsetb + $dy] = $tile;
      $dx++;
    }
    $dy++;
  }
  # The fill rules for inside an embed are different:
  # Instead of lava or rock, it can be lava or floor:
  for my $y (1 .. (scalar @embeda) - 2) {
    for my $x (1 .. (scalar @{$embeda[0]} - 2)) {
      my $newtile = (rand(100) > 60) ? lavatile() : floortile();
      maybefill($x + $xoffset, $y + $yoffset, 'UNDECIDED', $newtile);
      if ($map[$x + $xoffset][$y + $yoffset]{TERRAIN} eq 'LAVA') {
        $lavacount++;
      } else {
        $desiredlava-- if int rand(100) < int(50 + rand rand 15);
      }
    }
  }
  for my $y (1 .. (scalar @embedb) - 2) {
    for my $x (1 .. (scalar @{$embedb[0]} - 2)) {
      my $newtile = (rand(100) > 60) ? lavatile() : floortile();
      maybefill($x + $xoffsetb, $y + $yoffsetb, 'UNDECIDED', $newtile);
      if ($map[$x + $xoffsetb][$y + $yoffsetb]{TERRAIN} eq 'LAVA') {
        $lavacount++;
      } else {
        $desiredlava-- if int rand(100) < int(50 + rand rand 15);
      }
    }
  }
  $upx = 3 + int rand ($xoffset - 8);
  $upy = 2 + int rand ($rows - 4);
  $dnx = $xoffset + 13;
  $dny = $yoffset + 7;

} # TODO: other lairs.

my $x = int($cols / 2) + int rand($cols / 4);
my $y = int($rows / 2) + int rand($rows / 4);
while ($lavacount < $desiredlava) {
  if ($map[$x][$y]{TERRAIN} eq 'UNDECIDED') {
    $lavacount  += 1;
    $map[$x][$y] = +{ TERRAIN => 'LAVA',
                      GLYPH   => '}',
                      COLOR   => 'bold red',
                      BG      => 'on_black', };
  }
  my $switch = int rand 9;
  if ($switch < 3) {
    $x++;
    $x = 1 if $x >= ($cols - 1);
  } elsif ($switch < 6) {
    $x--;
    $x = $cols - 2 if $x <= 0;
  } elsif ($switch < 7) {
    $y++;
    $y = 1 if $y >= ($rows - 1);
  } elsif ($switch < 8) {
    $y--;
    $y = $rows - 2 if $y <= 0;
  } else {
    #showmap(); delay();
    if (25 > rand 50) {
      $x = int rand $cols;
      $x = 1 if $x >= ($cols - 1);
      $x = $cols - 2 if $x <= 0;
      $y = int rand $rows;
      $y = 1 if $y >= ($rows - 1);
      $y = $rows - 2 if $y <= 0;
    }
  }
}
if ($showprogress) {
  print "Map With Lava: \n"; showmap(); delay();
}

if ((not $upx) or (not $upy) or (not $dnx) or (not $dny)) {
  $upx = $dnx = int($cols / 2);
  $upy = $dny = int($rows / 2);
  while (abs($upx - $dnx) < ($cols / 2)) {
    $upx = 10 + int rand ($cols - 20);
    $upy =  3 + int rand ($rows - 6);
    $dnx = 10 + int rand ($cols - 20);
    $dny =  3 + int rand ($rows - 6);
    if ($showprogress) {
      print "UP: ($upx, $upy) \tDN: ($dnx, $dny)\n";
    }
  }
}

for my $dx ( -3 .. 3 ) {
  for my $dy ( (-1 * abs(3 - int(abs $dx / 2))) .. abs(3 - int(abs $dx / 2)) ) {
    fill($upx + $dx, $upy + $dy, 'UNDECIDED', floortile());
    fill($dnx + $dx, $dny + $dy, 'UNDECIDED', floortile()) unless $arg{lair} =~ /^asmo1/;
  }
}
$map[$upx][$upy] = +{ TERRAIN => 'FLOOR',
                      GLYPH   => '<',
                      COLOR   => 'bold white',
                      BG      => 'on_black',
                    };
$map[$dnx][$dny] = +{ TERRAIN => 'FLOOR',
                      GLYPH   => '>',
                      COLOR   => 'bold white',
                      BG      => 'on_black',
                    };
if ($showprogress) {
  print "Map With Stairs:\n"; showmap(); delay();
}

for my $y (0 .. $rows - 1) {
  fill(0, $y, 'UNDECIDED', rocktile(), 'force');
  if (rand(100) < 45) {
    fill(1, $y, 'UNDECIDED', rocktile());
  }
  fill($cols - 1, $y, 'UNDECIDED', rocktile(), 'force');
  if (rand(100) < 45) {
    fill($cols - 2, $y, 'UNDECIDED', rocktile());
  }
}
for my $x (0 .. $cols - 1) {
  fill($x, 0, 'UNDECIDED', rocktile(), 'force');
  if (rand(100) < 45) {
    fill($x, 1, 'UNDECIDED', rocktile());
  }
  fill($x, $rows - 1, 'UNDECIDED', rocktile(), 'force');
  if (rand(100) < 45) {
    fill($x, $rows - 2, 'UNDECIDED', rocktile());
  }
}
if ($showprogress) {
  print "Rock Around Edges:\n"; showmap(); delay();
}

for my $x (1 .. $cols - 2) {
  for my $y (1 .. $rows - 2) {
    my $newtile = (rand(100) > 60) ? rocktile() : floortile();
    maybefill($x, $y, 'UNDECIDED', $newtile);
  }
}
if ($showprogress) {
  print "Decided Middle:\n"; showmap(); delay();
}

my $canwalk  = sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR/; };
my $canfly   = sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR|LAVA/; };
my $canphase = $arg{lair}
  ? sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR|ROCK/; }
  : sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR|ROCK|WALL/; };
fillconnect($upx, $upy, $canwalk,  'walkto<', 'diag');
fillconnect($dnx, $dny, $canwalk,  'walkto>', 'diag');
fillconnect($upx, $upy, $canfly,   'flyto<');
fillconnect($dnx, $dny, $canfly,   'flyto>');
fillconnect($upx, $upy, $canphase, 'phaseto<', 'diag');
fillconnect($dnx, $dny, $canphase, 'phaseto>', 'diag');

my @trap = shuffle(
                   (['^', 'red', 'fire trap']) x 10,
                   (['^', 'yellow', 'pit']) x 10,
                   (['^', 'yellow', 'spiked pit']) x 5,
                   (['^', 'blue', 'anti-magic field']),
                   (['^', 'blue', 'magic trap']) x 3,
                  );
my @used = ();
my @placedtrap = ();
for (1 .. 4 + (int rand 5) + (int rand 5)
            + (int rand 5) + (int rand 5)) { # 4d5 pits
  if (not scalar @trap) {
    @trap = shuffle(@used); @used = ();
  }
  my $trap = shift @trap;
  my ($trapglyph, $trapcolor, $trapname) = @$trap;
  push @used, $trap;
  my $x = 2 + int rand($cols - 3);
  my $y = 1 + int rand($rows - 2);
  my $tries = 0;
  while (($tries++ < 1000) and not $map[$x][$y]{GLYPH} eq '.') {
    $x = 2 + int rand($cols - 3);
    $y = 1 + int rand($rows - 2);
  }
  $map[$x][$y]{GLYPH} = $trapglyph;
  $map[$x][$y]{COLOR} = $trapcolor;
  push @placedtrap, qq[$trapname ($x,$y)];
}
if ($showprogress) {
  print "With Traps:\n"; showmap(); delay();
  print "Traps: " . (join ", ", @placedtrap) . "\n";
}


my @flyingmonster = shuffle(
                            (['e', 'red',    'flaming sphere']) x 2,
                            (['v', 'red',    'fire vortex']) x 2,
                            (['y', 'bold black',  'black light']),
                            (['D', 'red',    'red dragon']) x 4,
                            (['E', 'bold yellow', 'fire elemental']) x 3,
                           );
my @othermonster = shuffle(
                           (['a', 'red', 'fire ant']),
                           (['c', 'red', 'pyrolisk']),
                           (['d', 'red', 'hellhound']) x 2,
                           (['E', 'yellow', 'earth elemental']),
                           (['F', 'red', 'red mold']),
                           (['H', 'bold yellow', 'fire giant']) x 2,
                           (['L', 'magenta', (rand(100) > 50) ? 'master lich' : 'arch-lich']),
                           (['N', 'red', 'red naga']) x 2,
                           (['X', 'yellow', 'xorn']) x 4,
                           (['&', 'yellow', 'horned devil']) x 2,
                           (['&', 'white', 'incubus']),
                           (['&', 'white', 'succubus']),
                           (['&', 'red', 'barbed devil']) x 2,
                           (['&', 'red', 'maralith']),
                           (['&', 'red', 'vrock']),
                           (['&', 'white', 'bone devil']),
                           (['&', 'red', 'nalfeshnee']),
                           (['&', 'red', 'pit fiend']) x 4,
                           (['&', 'red', 'balrog']),
                           ([':', 'red', 'salamander']) x 2, # Term::ANSIColor doesn't support orange.
                          );
my @used = ();
my @monster = ();
if ($arg{lair} eq 'geryon') {
  my ($gx, $gy) = (0,0); # relative to the offsets
  my $switch = int rand 6;
  if ($switch == 0) {
    ($gx, $gy) = (24, 1);
  } elsif ($switch == 1) {
    ($gx, $gy) = (15, 5);
  } elsif ($switch == 2) {
    ($gx, $gy) = (29, 9);
  } elsif ($switch == 3) {
    ($gx, $gy) = (6, 12);
  } elsif ($switch == 4) {
    ($gx, $gy) = (11, 16);
  } else {
    ($gx, $gy) = (2, 18);
  }
  $map[$xoffset + $gx][$yoffset + $gy]{GLYPH} = '&';
  $map[$xoffset + $gx][$yoffset + $gy]{COLOR} = 'magenta';
  push @monster, qq[Geryon (] . ($xoffset + $gx) . ',' . ($yoffset + $gy) . qq[)];
} elsif ($arg{lair} eq 'asmo2') {
  push @monster, qq[Asmodeus(on >, not shown)];
  my @asmocompanion = shuffle(
                              (['L', 'magenta', 'master lich']),
                              (['&', 'white', 'sandestin']) x 4,
                              (['&', 'red', 'barbed devil']) x 2,
                              (['&', 'red', 'maralith']),
                              (['&', 'red', 'vrock']),
                              (['&', 'white', 'bone devil']),
                              (['&', 'red', 'nalfeshnee']),
                              (['&', 'red', 'pit fiend']) x 4,
                              (['&', 'red', 'balrog']),
                             );
  for (1 .. 3 + int rand 3) {
    my $monster = shift @asmocompanion;
    my ($monglyph, $moncolor, $monname) = @$monster;
    my $x = $xoffset + 7 + int rand 9;
    my $y = $yoffset + 4 + int rand 4;
    my $tries = 0;
    while (($tries++ < 20)
           and not $map[$x][$y]{GLYPH} =~ /[.]/) {
      $x = $xoffset + 7 + int rand 9;
      $y = $yoffset + 4 + int rand 4;
    }
    $map[$x][$y]{GLYPH} = $monglyph;
    $map[$x][$y]{COLOR} = $moncolor;
    my $getto     = '';
    $getto       .= "<" if $map[$x][$y]{CONNECT}{$transmode.'walk<'};
    $getto       .= ">" if $map[$x][$y]{CONNECT}{$transmode.'walk>'};
    $getto        = ",$getto" if $getto;
    push @monster, qq[$monname ($x,$y$getto)];
  }
}
for (1 .. 4 + (int rand 3) + (int rand 3)
            + (int rand 3) + (int rand 3)) { # 4d3 non-flying monsters
  if (not scalar @othermonster) {
    @othermonster = shuffle(@used); @used = ();
  }
  my $monster = shift @othermonster;
  my ($monglyph, $moncolor, $monname) = @$monster;
  push @used, $monster;
  my $x = 2 + int rand($cols - 3);
  my $y = 1 + int rand($rows - 2);
  my $pattern  = ($monname eq 'xorn') ? qr/ / : qr/[.]/;
  my $conntype = ($monname eq 'xorn') ? 'phase' : 'fly';
  my $tries = 0;
  while (($tries++ < 1000)
         and (   (not $map[$x][$y]{GLYPH} =~ $pattern)
              or (    (not $map[$x][$y]{CONNECT}{$conntype.'to<'})
                  and (not $map[$x][$y]{CONNECT}{$conntype.'to>'})))) {
    $x = 2 + int rand($cols - 3);
    $y = 1 + int rand($rows - 2);
  }
  $map[$x][$y]{GLYPH} = $monglyph;
  $map[$x][$y]{COLOR} = $moncolor;
  my $getto     = '';
  my $transmode = ($monname eq 'xorn') ? "phase" : "walk";
  $getto       .= "<" if $map[$x][$y]{CONNECT}{$transmode.'to<'};
  $getto       .= ">" if $map[$x][$y]{CONNECT}{$transmode.'to>'};
  $getto        = ",$getto" if $getto;
  push @monster, qq[$monname ($x,$y$getto)];
}
if ($showprogress) {
  print "With Ground-Based Monsters:\n"; showmap(); delay();
}

for (1 .. 5 + (int rand 3) + (int rand 3)
     + (int rand 3) + (int rand 3) + (int rand 3)) { # 5d3 flying monsters
  if (not scalar @flyingmonster) {
    @flyingmonster = shuffle(@used); @used = ();
  }
  my $monster = shift @flyingmonster;
  my ($monglyph, $moncolor, $monname) = @$monster;
  push @used, $monster;
  my $x = 2 + int rand($cols - 3);
  my $y = 1 + int rand($rows - 2);
  my $tries = 0;
  while (($tries < 1000)
         and ((not $map[$x][$y]{GLYPH} =~ /[}.]/)
              or (    (not $map[$x][$y]{CONNECT}{'flyto<'})
                  and (not $map[$x][$y]{CONNECT}{'flyto>'})))) {
    $x = 2 + int rand($cols - 3);
    $y = 1 + int rand($rows - 2);
  }
  $map[$x][$y]{GLYPH} = $monglyph;
  $map[$x][$y]{COLOR} = $moncolor;
  my $getto = '';
  $getto   .= "<" if $map[$x][$y]{CONNECT}{'flyto<'};
  $getto   .= ">" if $map[$x][$y]{CONNECT}{'flyto>'};
  $getto    = ",$getto" if $getto;
  push @monster, qq[$monname ($x,$y$getto)];
}
if ($showprogress) {
  print "With Flying Monsters:\n";
}
print "UP: ($upx, $upy) \tDN: ($dnx, $dny)\n";
showmap(); delay();
print "Walkable: " . ($map[$upx][$upy]{CONNECT}{'walkto>'} ? 'yes'
                      : ('no' .
                         " (with digging: "
                         . ($map[$upx][$upy]{CONNECT}{'phaseto>'} ? 'yes)' : 'no)'))) ."\n";
print "Flyable: "  . ($map[$upx][$upy]{CONNECT}{'flyto>'}  ? 'yes' : 'no') . "\n";
print "Traps: " . (join ", ", @placedtrap) . "\n";
print "Monsters: " . (join ", ", @monster) . "\n";
print "\n";
exit 0; # Subroutines follow

sub showmap {
  print "\n";
  for my $y (0 .. $rows - 1) {
    for my $x (0 .. $cols - 1) {
      print color qq<$map[$x][$y]{COLOR} $map[$x][$y]{BG}>;
      print $map[$x][$y]{GLYPH};
      print color 'reset';
    }
    print "\n";
  }
  print "\n";
}

sub shuffle { # I know this isn't optimal.  I don't care.
  return map {
    $$_[0]
  } sort {
    $$a[1] <=> $$b[1]
  } map {
    [$_ => rand(42) ]
  } @_;
}

sub floortile {
  return +{ TERRAIN => 'FLOOR',
            GLYPH   => '.',
            COLOR   => 'yellow',
            BG      => 'on_black',
          };
}
sub rocktile {
  return +{ TERRAIN => 'ROCK',
            GLYPH   => ' ',
            COLOR   => 'black',
            BG      => 'on_black',
          };
}
sub lavatile {
  return +{ TERRAIN => 'LAVA',
            GLYPH   => '}',
            COLOR   => 'bold red',
            BG      => 'on_black',
          };
}

sub copytile {
  my ($src) = @_;
  return +{ map { $_ => $$src{$_} } keys %$src  };
}

sub maybefill {
  my ($x, $y, $oldterrain, $newtile) = @_;
  if (($x > 0) and ($x < $cols - 1) and
      ($y > 0) and ($y < $rows - 1) and
      $map[$x][$y]{TERRAIN} =~ $oldterrain) {
    fill($x, $y, $oldterrain, $newtile);
  }
}

sub fill {
  my ($x, $y, $oldterrain, $newtile, $force) = @_;
  if (not $force) {
    return if $x < 1;
    return if $x > $cols - 2;
    return if $y < 1;
    return if $y > $rows - 2;
  }
  $map[$x][$y] = copytile($newtile);
  for my $dx ( -1 .. 1 ) {
    maybefill($x + $dx, $y, $oldterrain, $newtile);
  }
  for my $dy ( -1 .. 1 ) {
    maybefill($x, $y + $dy, $oldterrain, $newtile);
  }
}

sub maybefillconnect {
  my ($x, $y, $callback, $target, $diag) = @_;
  if (($x >= 0) and ($x <= $cols - 1) and
      ($y >= 0) and ($y <= $rows - 1) and
      $callback->($map[$x][$y])) {
    fillconnect($x, $y, $callback, $target, $diag);
  }
}

sub fillconnect {
  my ($x, $y, $callback, $target, $diag) = @_;
  return if $x < 0;
  return if $x > $cols - 1;
  return if $y < 0;
  return if $y > $rows - 1;
  return if $map[$x][$y]{CONNECT}{$target};
  $map[$x][$y]{CONNECT}{$target} = 1;
  if ($diag) {
    for my $dx ( -1 .. 1 ) {
      for my $dy ( -1 .. 1 ) {
        maybefillconnect($x + $dx, $y + $dy, $callback, $target, $diag);
      }
    }
  } else {
    for my $dx ( -1 .. 1 ) {
      maybefillconnect($x + $dx, $y, $callback, $target);
    }
    for my $dy ( -1 .. 1 ) {
      maybefillconnect($x, $y + $dy, $callback, $target);
    }
  }
}

sub parseembed {
  return map {
    [ map {
      my $char = $_;
      my $tile = +{
                   TERRAIN => 'FLOOR',
                   ROOM    => 'Geryon',
                   GLYPH   => $char,
                   BG      => 'on_black',
                  };
      if ($char =~ /[-|]/) {
        $$tile{TERRAIN} = 'WALL';
        $$tile{COLOR}   = 'white';
      } elsif ($char eq '.') {
        $$tile{TERRAIN} = 'FLOOR';
        $$tile{COLOR}   = 'yellow';
      } elsif ($char eq ' ') {
        $$tile{TERRAIN} = 'ROCK';
        $$tile{COLOR}   = 'bold black';
      } elsif ($char eq 'S') {
        $$tile{TERRAIN} = 'DOOR';
        $$tile{SECRET}  = 'YES';
        $$tile{GLYPH}   = '+';
        $$tile{COLOR}   = 'bold black';
      } elsif ($char eq '?') {
        $$tile{TERRAIN} = 'UNDECIDED';
        $$tile{COLOR}   = 'magenta';
      } elsif ($char eq 'L') {
        $$tile{TERRAIN} = 'LAVA';
        $$tile{COLOR}   = 'bold red';
        $$tile{GLYPH}   = '}';
      }
      $tile;
    } split //, $_]
  } @_;
}
