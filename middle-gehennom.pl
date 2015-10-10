#!/usr/bin/perl
# -*- cperl -*-

use Term::ANSIColor;
use strict;

$|=1;
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
    $arg{lair}   = (rand(100) > 50) ? 'asmo2' : 'asmo1';
    $arg{branch} = 'firepits';
  } elsif ($arg =~ /^baal/) {
    $arg{lair}   = (rand(100) > 50) ? 'baal1' : 'baal2';
    $arg{branch} = 'firepits';
  } elsif ($arg =~ /^yee/) {
    $arg{lair}   = 'yeenoghu';
    $arg{branch} = 'firepits';
  } elsif ($arg =~ /^disp/) {
    $arg{lair}   = 'dis';
    $arg{branch} = 'firepits';
  } elsif ($arg =~ /^ju[ib]+lex/) {
    $arg{lair}   = 'juiblex';
    $arg{branch} = 'swamp';
  } elsif ($arg =~ /^demo(g|\b)/) {
    $arg{lair}   = 'demo';
    $arg{branch} = 'swamp';
  } elsif ($arg =~ /^nolair/) {
    $arg{lair}   = 'none';
  } elsif ($arg =~ /^fire/) {
    $arg{branch} = 'firepits';
  } elsif ($arg =~ /^swamp/) {
    $arg{branch} = 'swamp'; # of death
  } elsif ($arg =~ /showprogress/) {
    $arg{$arg} = 1;
  } else {
    warn "Did not understand argument: $arg\n";
  }
}
my $rows  = $arg{rows} || 22;
my $cols  = $arg{cols} || 80;
my $showprogress = $arg{showprogress};
$arg{branch} ||= (rand(100) > 50) ? 'swamp' : 'firepits';
$arg{lair}   ||= randomlair($arg{branch});
my @monster = ();

my %branchtitle = ( firepits => 'The Fire Pits',
                    swamp    => 'Swamp of Death');
my %lairtitle = (
                 asmo1    => "Asmodeus' Lair (A)",
                 asmo2    => "Asmodeus' Lair (B)",
                 baal1    => "Baalzebub's Fortress (A)",
                 baal2    => "Baalzebub's Fortress (B)",
                 yeenoghu => "Yeenoghu's Plaza",
                 dis      => "Dispater's Gauntlet",
                 juiblex  => "Juiblex' Quagmire",
                 demo     => "Demogorgon's Bayou Village",
                 none     => "Filler Level",
                );

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

# Initialize some other variables...
my ($upx, $upy, $dnx, $dny) = (0, 0, 0, 0);
my ($xoffset, $yoffset)     = (0, 0); # offset for most important embedded content
my ($xoffsetb, $yoffsetb)   = (0, 0); # some lairs have a second embed
my ($xoffsetc, $yoffsetc)   = (0, 0); # ... and a third ...
my ($xoffsetd, $yoffsetd)   = (0, 0); # ... maybe even a fourth.
my $size = $rows * $cols;
my $desiredlava = ($arg{branch} eq 'firepits') ? int((50 + rand rand 15) * $size / 100)
  : ($arg{branch} eq 'swamp') ? 0
  : int((10 + rand rand 35) * $size / 100);
my $desiredwater = ($arg{branch} eq 'swamp') ? int((40 + rand rand 25) * $size / 100)
  : ($arg{branch} eq 'firepits') ? 0
  : int((5 + rand rand 25) * $size / 100);
my ($lavacount, $watercount);

if ($showprogress) {
  print "Blank Map: \n"; showmap(); delay();
}

# ******************* Embed possible special components:

if ($arg{lair} eq 'yeenoghu') {
  print $lairtitle{$arg{lair}} . ":\n";
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
  ($xoffset, $yoffset) = embedcenter(@embed);
  print "Embedding lair at ($xoffset,$yoffset)\n";
  $desiredlava -= 100; # Mostly to account for the walls.
  placeembed([@embed], $xoffset, $yoffset);
  fillundecidedareas($xoffset + 1, $yoffset + 1,
                     $xoffset + (scalar @{$embed[0]} - 2), $yoffset + ((scalar @embed) - 2),
                     [  40 => floortile() ],
                     [ 101 => lavatile() ],
                    );

  $upx = 2 + int rand ($xoffset - 4);
  $dnx = $cols - 2 - int rand ($xoffset - 4);
  $upy = 2 + int rand ($rows - 4);
  $dny = 2 + int rand ($rows - 4);
  if ($showprogress) {
    print "Embedded " . $lairtitle{$arg{lair}} . "\n"; showmap(); delay();
  }
} elsif ($arg{lair} eq 'dis') {
  print $lairtitle{$arg{lair}} . ":\n";
  my @embed = parseembed(#          1111111111222222222233
                         # 1234567890123456789012345678901
                         '                                ',
                         '?                        ----- ?',# 1
                         'L --- --- -------    -----#..| ?',# 2
                         '? |.| |.| |.#...| ----.--.###---',# 3
                         '? |.| |.| |.#...| |..#.......?.|',# 4
                         ' --?---?---?####---..#.--.--.---',# 5
                         '.+.............?..#..#.| ---.---',# 6
                         ' |?|--?--?-#--.|---..#.| |.?...+',# 7
                         ' |.| |.||.|..#.|  ----.-----?---',# 8
                         ' --- |.||.|..#.|  |..?..---|.|  ',# 9
                         '?    ------#--.----####.?..|.|  ',#10
                         '? ----...........#....#.?----- ?',#11
                         '? |..?.--.----#-.######+-----  ?',#12
                         'L ----.--#----.---......#...| ?L',#13
                         '?    |.............----?|---- L?',#14
                         '? ?? |.---?---?---?-  |.| ???? ?',#15
                         'L??? |.| |.| |.| |.| .S.| ????L?',#16
                         '? ?? --- |.| |.| ---  ---  ??  ?',#17
                         '?        --- ---               ?',#18
                         '                                ',);
  # We want to center it:
  ($xoffset, $yoffset) = embedcenter(@embed);
  print "Embedding lair at ($xoffset,$yoffset)\n";
  placeembed([@embed], $xoffset, $yoffset);
  $desiredlava -= 180;
  fillundecidedareas($xoffset + 1, $yoffset + 1,
                     $xoffset + (scalar @{$embed[0]} - 2), $yoffset + ((scalar @embed) - 2),
                     [  50 => floortile() ],
                     [ 101 => lavatile() ],
                    );
  $upx = 2 + int rand ($xoffset - 4);
  $dnx = $cols - 2 - int rand ($xoffset - 4);
  $upy = 2 + int rand ($rows - 4);
  $dny = 2 + int rand ($rows - 4);
  if ($showprogress) {
    print "Embedded Dispater's Gauntlet: \n"; showmap(); delay();
  }
} elsif ($arg{lair} eq 'baal1') {
  print $lairtitle{$arg{lair}} . ":\n";
  my @embed = parseembed('?L??      ??L????   ???L',
                         '?                      ?',
                         '  ------------ ------- ?',
                         'L |??L???L???|-|.....|  ',
                         'L +.??L?.?L?.+.+..>..|  ',
                         'L |??.?L???.?|-|.....| ?',
                         '  ------------ -------  ',
                         '?                      ?',
                         '?L????    ???  ????   ??',
                         );
  my $xoffset = int($cols / 2) + int rand (int($cols / 2) - @{$embed[0]} - 2);
  my $yoffset = 4 + int rand($rows - (scalar @embed) - 8);
  $desiredlava -= 100;
  placeembed([@embed], $xoffset, $yoffset);
  # Inside, fill undecided areas with lava or floor:
  fillundecidedareas($xoffset + 1, $yoffset + 1,
                     $xoffset + (scalar @{$embed[0]} - 2), $yoffset + ((scalar @embed) - 2),
                     [  40 => floortile() ],
                     [ 101 => lavatile() ],
                    );
  $upx = 2 + int rand (($cols / 3) - 5);
  $upy = 2 + int rand ($rows - 4);
  $dnx = $xoffset + 18;
  $dny = $yoffset + 4;
  if ($showprogress) {
    print "Embedded $lairtitle{$arg{lair}}\n"; showmap(); delay();
  }
  my $baly = 3 + int rand 3;
  $map[$xoffset + 17][$yoffset + $baly]{GLYPH} = '&';
  $map[$xoffset + 17][$yoffset + $baly]{COLOR} = 'magenta';
  push @monster, qq[Baalzebub (] . ($xoffset + 17) . ',' . ($yoffset + $baly) . qq[)];

} elsif ($arg{lair} eq 'baal2') {
  print "$lairtitle{$arg{lair}}:\n";
  my @embed = parseembed('?L????LL????L???L??',
                         '?                 ?',
                         '? -------+------- ?',
                         'L |??L???.???L??| ?',
                         '? |???.?L?L?.???| L',
                         '? ----+-----+---- ?',
                         '?   |LLLLLLLLL|   ?',
                         'L?  |L??.?.??L|  ?L',
                         ' ?  |L.L?>?L.L|  ? ',
                         'L?  |L??.?.??L|  ?L',
                         '?   |LLLLLLLLL|   ?',
                         '? ----+-----+---- ?',
                         '? |???.?L?L?.???| ?',
                         'L |??L???.???L??| L',
                         '? -------+------- ?',
                         '?                 ?',
                         '??L????L????LL???L?',
                         );
  my $xoffset = int($cols / 2) + int rand (int($cols / 2) - @{$embed[0]} - 2);
  my $yoffset = 4 + int rand($rows - (scalar @embed) - 8);
  $desiredlava -= 100;
  placeembed([@embed], $xoffset, $yoffset);
  # Inside, fill undecided areas with lava or floor:
  fillundecidedareas($xoffset + 2, $yoffset + 2,
                     $xoffset + (scalar @{$embed[0]} - 4), $yoffset + ((scalar @embed) - 4),
                     [  40 => floortile() ],
                     [ 101 => lavatile() ],
                    );
  $upx = 2 + int rand (($cols / 3) - 5);
  $upy = 2 + int rand ($rows - 4);
  $dnx = $xoffset + 9;
  $dny = $yoffset + 8;
  my $baalxoff = (rand(100)>50) ? 1 : -1;
  my $baalyoff = (rand(100)>50) ? 1 : -1;
  $map[$dnx + $baalxoff][$dny + $baalyoff]{GLYPH} = '&';
  $map[$dnx + $baalxoff][$dny + $baalyoff]{COLOR} = 'magenta';
  push @monster, qq[Baalzebub (] . ($dnx + $baalxoff) . ',' . ($dny + $baalyoff) . qq[)];
  if ($showprogress) {
    print "Embedded $lairtitle{$arg{lair}}\n"; showmap(); delay();
  }

} elsif ($arg{lair} eq 'asmo2') {
  print "$lairtitle{$arg{lair}}:\n";
  my @embed = parseembed('----------------------------------S---',
                         '|L??....??L?..???.?? LL..???|???...??|',
                         '|??...??.? L?.?..????L....??|??.??..?|',
                         '| .?.???-------S--------S-------?..?L|',
                         '|.?.L..L...|??.?.???L.??.?.???L+..???|',
                         '|L.????..>.|?..LL??L.?.?...??LL------|',
                         '|??.??.....|??.?.??.???L?L??L?L+..???|',
                         '| ??.L..-------S--------S-------??.??|',
                         '|.??L??.L?? .??.?.???LL..???|???.??.L|',
                         '|.LLL.???.LL??.???.??.L ??.L|??LL..LL|',
                         '----------------------------------S---',
                        );
  ($xoffset, $yoffset) = embedcenter(@embed);
  print "Embedding lair at ($xoffset,$yoffset)\n";
  $desiredlava -= 80; # Mostly to account for the walls.
  placeembed([@embed], $xoffset, $yoffset);
  # Inside, fill undecided areas with lava or floor:
  fillundecidedareas($xoffset + 1, $yoffset + 1,
                     $xoffset + (scalar @{$embed[0]} - 2), $yoffset + ((scalar @embed) - 2),
                     [  40 => floortile() ],
                     [ 101 => lavatile() ],
                    );

  $upx = 2 + int rand ($xoffset - 4);
  $upy = 2 + int rand ($rows - 4);
  $dnx = $xoffset + 9;
  $dny = $yoffset + 5;
  if ($showprogress) {
    print "Embedded $lairtitle{$arg{lair}}: \n"; showmap(); delay();
  }
} elsif ($arg{lair} eq 'asmo1') {
  print "$lairtitle{$arg{lair}}:\n";
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
  placeembed([@embeda], $xoffset, $yoffset);
  placeembed([@embedb], $xoffsetb, $yoffsetb);
  # Inside, fill undecided areas with either lava or floor:
  fillundecidedareas($xoffset + 1, $yoffset + 1,
                     $xoffset + (scalar @{$embeda[0]} - 2), $yoffset + ((scalar @embeda) - 2),
                     [  40 => floortile() ],
                     [ 101 => lavatile() ],
                    );
  fillundecidedareas($xoffsetb + 1, $yoffsetb + 1,
                     $xoffsetb + (scalar @{$embedb[0]} - 2), $yoffsetb + ((scalar @embedb) - 2),
                     [  40 => floortile() ],
                     [ 101 => lavatile() ],
                    );
  $upx = 3 + int rand ($xoffset - 8);
  $upy = 2 + int rand ($rows - 4);
  $dnx = $xoffset + 13;
  $dny = $yoffset + 7;

} elsif ($arg{lair} eq 'demo') {
  print "$lairtitle{$arg{lair}}:\n";
  my @embeddable = shuffle((['??---??',
                             '??...??',
                             '??-+-??',
                             '??|.|??',
                             '??---??',
                             '???????',
                             '???????',]) x 2,
                           (['???????',
                             '???????',
                             '??---??',
                             '??|.|??',
                             '??-+-??',
                             '???????',
                             '??---??',]) x 2,
                           (['???????',
                             '???????',
                             '|.---??',
                             '|.+.|??',
                             '|.---??',
                             '???????',
                             '???????',]) x 2,
                           (['???????',
                             '???????',
                             '??---.|',
                             '??|.+.|',
                             '??---.|',
                             '???????',
                             '???????',]) x 2,);
  my @embeda  = parseembed(@{shift @embeddable});
  my @embedb  = parseembed(@{shift @embeddable});
  my @embedc  = parseembed(@{shift @embeddable});
  my @embedd  = parseembed(@{shift @embeddable});
  my @upembed = parseembed(@{shift @embeddable});
  my @dnembed = parseembed(@{shift @embeddable});
  # A is where the lamp is; Demogorgon also starts there (but, he probably won't stay put).
  # B, C, and D are decoys; each of them gets a demon of some kind.
  # Up and Dn are where the stairs go.
  ($xoffset, $yoffset, $xoffsetb, $yoffsetb, $xoffsetc, $yoffsetc, $xoffsetd, $yoffsetd)
    = (0,0,0,0,0,0,0,0);
  ($upx, $upy, $dnx, $dny) = (0,0,0,0);
    my $tries = $cols * 100 / 4;
  while (((abs($upx - $dnx) < $cols / 2) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@embedb], $xoffsetb, $yoffsetb, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@embedc], $xoffsetc, $yoffsetc, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@embedd], $xoffsetd, $yoffsetd, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedb], $xoffsetb, $yoffsetb, [@embedc], $xoffsetc, $yoffsetc, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedb], $xoffsetb, $yoffsetb, [@embedd], $xoffsetd, $yoffsetd, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedc], $xoffsetc, $yoffsetc, [@embedd], $xoffsetd, $yoffsetd, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@upembed], $upx - 3, $upy - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@dnembed], $dnx - 3, $dny - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedb], $xoffsetb, $yoffsetb, [@upembed], $upx - 3, $upy - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedb], $xoffsetb, $yoffsetb, [@dnembed], $dnx - 3, $dny - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedc], $xoffsetc, $yoffsetc, [@upembed], $upx - 3, $upy - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedc], $xoffsetc, $yoffsetc, [@dnembed], $dnx - 3, $dny - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedd], $xoffsetd, $yoffsetd, [@upembed], $upx - 3, $upy - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedd], $xoffsetd, $yoffsetd, [@dnembed], $dnx - 3, $dny - 3,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@upembed], $upx - 4, $upy - 2,  [@dnembed], $dnx - 3, $dny - 3,  1 + int($cols / 2), int($rows / 2))))
         and $tries) {
    ($xoffset,  $yoffset)  = embedrandompos(@embeda);
    ($xoffsetb, $yoffsetb) = embedrandompos(@embedb);
    ($xoffsetc, $yoffsetc) = embedrandompos(@embedb);
    ($xoffsetd, $yoffsetd) = embedrandompos(@embedb);
    $upx = 5 + int rand($cols / 3 - 10);
    $upy = 5 + int rand($rows - 10);
    $dnx = $cols - 5 - int rand($cols / 3 - 10);
    $dny = $rows - 5 - int rand($rows - 10);
    $tries--;
  }
  placeembed([@embedd], $xoffsetd, $yoffsetd);
  placeembed([@embedc], $xoffsetc, $yoffsetc);
  placeembed([@embedb], $xoffsetb, $yoffsetb);
  placeembed([@embeda], $xoffset, $yoffset);
  placeembed([@upembed], $upx - 3, $upy - 3);
  placeembed([@dnembed], $dnx - 3, $dny - 3);
  $desiredwater -= 120;
  $map[$xoffset + 3][$yoffset + 3]{GLYPH} = '&';
  $map[$xoffset + 3][$yoffset + 3]{COLOR} = 'magenta';
  push @monster, qq[Demogorgon (] . ($xoffset + 3) . ',' . ($yoffset + 3) . qq[)];
  $map[$xoffsetb + 3][$yoffsetb + 3]{GLYPH} = '&';
  $map[$xoffsetb + 3][$yoffsetb + 3]{COLOR} = 'red';
  push @monster, qq[nalfeshnee (] . ($xoffsetb + 3) . ',' . ($yoffsetb + 3) . qq[)];
  $map[$xoffsetc + 3][$yoffsetc + 3]{GLYPH} = '&';
  $map[$xoffsetc + 3][$yoffsetc + 3]{COLOR} = 'red';
  push @monster, qq[balrog (] . ($xoffsetc + 3) . ',' . ($yoffsetc + 3) . qq[)];
  $map[$xoffsetd + 3][$yoffsetd + 3]{GLYPH} = '&';
  $map[$xoffsetd + 3][$yoffsetd + 3]{COLOR} = 'white';
  push @monster, qq[bone devil (] . ($xoffsetd + 3) . ',' . ($yoffsetd + 3) . qq[)];

} elsif ($arg{lair} eq 'juiblex') {
  print "$lairtitle{$arg{lair}}:\n";
  my @embeda = parseembed('??WWWWW??',
                          '?WW...WW?',
                          'WW..P..WW',
                          'W..P.P..W',
                          'WW..P..WW',
                          '?WW...WW?',
                          '??WWWWW??',);
  my @embedb = parseembed('?WWWWWWW?',
                          'WW.....WW',
                          'W..P.P..W',
                          'WW.....WW',
                          '?WW...WW?',
                          '?WW...WW?',
                          '??WWWWW??',);
  my @upembed = parseembed('WWWWWW??',
                           'WW...WW?',
                           '?WW...WW',
                           '??WW.WW?',
                           '???WWWW?',);
  my @dnembed = parseembed('???WWWW?',
                           '??WW.WW?',
                           '?WW...WW',
                           'WW...WW?',
                           '?WWWWW??',);
  ($xoffset, $yoffset, $xoffsetb, $yoffsetb) = (0,0,0,0);
  ($upx, $upy, $dnx, $dny) = (0,0,0,0);
  my $tries = $cols * 100 / 4;
  while (((abs($upx - $dnx) < $cols / 2) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@embedb], $xoffsetb, $yoffsetb, 1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@upembed], $upx - 4, $upy - 2,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embeda], $xoffset,  $yoffset,  [@dnembed], $dnx - 4, $dny - 2,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedb], $xoffsetb, $yoffsetb, [@upembed], $upx - 4, $upy - 2,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@embedb], $xoffsetb, $yoffsetb, [@dnembed], $dnx - 4, $dny - 2,  1 + int($tries / 100), int($tries * $rows / $cols / 100))) or
          (embedoverlap([@upembed], $upx - 4, $upy - 2,  [@dnembed], $dnx - 4, $dny - 2,  1 + int($cols / 2), int($rows / 2))))
         and $tries) {
    ($xoffset,  $yoffset)  = embedrandompos(@embeda);
    ($xoffsetb, $yoffsetb) = embedrandompos(@embedb);
    $upx = 6 + int rand($cols / 3 - 12);
    $upy = 4 + int rand($rows - 8);
    $dnx = $cols - 6 - int rand($cols / 3 - 12);
    $dny = $rows - 4 - int rand($rows - 8);
    #warn "$tries tries: ($xoffset,$yoffset) / ($xoffsetb,$yoffsetb) / ($upx,$upy) / ($dnx,$dny)\n";
    #($upx, $upy)           = embedrandompos(@upembed); $upx += 4; $upy += 2; # stairs are offset within the embed
    #($dnx, $dny)           = embedrandompos(@dnembed); $dnx += 4; $dnx += 2; # stairs are offset within the embed
    $tries--;
  }
  placeembed([@embedb], $xoffsetb, $yoffsetb);
  placeembed([@embeda], $xoffset, $yoffset);
  placeembed([@upembed], $upx - 4, $upy - 2);
  placeembed([@dnembed], $dnx - 4, $dny - 2);
  $desiredwater -= 120;
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

while ($watercount < $desiredwater) {
  my $x = 1 + int rand($cols - 2);
  my $y = 1 + int rand($rows - 2);
  if ($map[$x][$y]{TERRAIN} eq 'UNDECIDED') {
    my $adjwater = 0;
    for my $dx (-1 .. 1) {
      for my $dy (-1 .. 1) {
        if ((($dx != 0) or ($dy != 0)) and
            ($map[$x + $dx][$y + $dy]{TERRAIN} eq 'WATER')) {
          $adjwater++;
        }
      }
    }
    if (rand($adjwater * $adjwater) < (10 * ($desiredwater + 1) / ($watercount + 1))) {
      $watercount  += 1;
      $map[$x][$y] = +{ TERRAIN => 'WATER',
                        GLYPH   => '}',
                        COLOR   => 'bold cyan',
                        BG      => 'on_blue', };
    }
  }
}

if ($showprogress) {
  print "Map With Water: \n"; showmap(); delay();
}

if ($arg{branch} eq 'swamp') {
  my $xstep = 2 + int rand 5;
  my $ystep = 1 + int rand 3;
  for my $x ( 0 .. int($cols / $xstep)) {
    for my $y ( 0 .. int($cols / $ystep)) {
      my $dx = int rand $xstep;
      my $dy = int rand $ystep;
      if ($map[$x * $xstep + $dx][$y * $ystep + $dy]{TERRAIN} eq 'UNDECIDED') {
        $map[$x * $xstep + $dx][$y * $ystep + $dy] = +{ TERRAIN => 'FLOOR',
                                                        GLYPH   => '.',
                                                        COLOR   => 'yellow',
                                                        BG      => 'on_black', };
      }
    }
  }
  if ($showprogress) {
    print "Map With Tiny Islands: \n"; showmap(); delay();
  }
}

if ((not $upx) or (not $upy) or (not $dnx) or (not $dny)) {
  $upx = $dnx = int($cols / 2);
  $upy = $dny = int($rows / 2);
  my $minspan = 0.9;
  while (abs($upx - $dnx) < ($cols * $minspan)) {
    $upx = 10 + int rand ($cols - 20);
    $upy =  3 + int rand ($rows - 6);
    $dnx = 10 + int rand ($cols - 20);
    $dny =  3 + int rand ($rows - 6);
    $minspan -= 0.001;
    if ($showprogress) {
      print "UP: ($upx, $upy) \tDN: ($dnx, $dny) \tSPAN: " . abs($upx - $dnx) . " (MIN: $minspan)\n";
    }
  }
}

for my $dx ( -3 .. 3 ) {
  for my $dy ( (-1 * abs(3 - int(abs $dx / 2))) .. abs(3 - int(abs $dx / 2)) ) {
    fill($upx + $dx, $upy + $dy, 'UNDECIDED', floortile()) if $arg{lair} =~ /^(none|yeen|dis|baal|asmo)/;
    fill($dnx + $dx, $dny + $dy, 'UNDECIDED', floortile()) if $arg{lair} =~ /^(none|yeen|dis)/;
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

my $edgetile = ($arg{branch} eq 'swamp') ? watertile() : rocktile();

for my $y (0 .. $rows - 1) {
  fill(0, $y, 'UNDECIDED', $edgetile, 'force');
  if ((rand(100) < 45) and ($arg{branch} ne 'swamp')) {
    fill(1, $y, 'UNDECIDED', $edgetile);
  }
  fill($cols - 1, $y, 'UNDECIDED', $edgetile, 'force');
  if ((rand(100) < 45) and ($arg{branch} ne 'swamp')) {
    fill($cols - 2, $y, 'UNDECIDED', $edgetile);
  }
}
for my $x (0 .. $cols - 1) {
  fill($x, 0, 'UNDECIDED', $edgetile, 'force');
  if ((rand(100) < 45) and ($arg{branch} ne 'swamp')) {
    fill($x, 1, 'UNDECIDED', $edgetile);
  }
  fill($x, $rows - 1, 'UNDECIDED', $edgetile, 'force');
  if ((rand(100) < 45) and ($arg{branch} ne 'swamp')) {
    fill($x, $rows - 2, 'UNDECIDED', $edgetile);
  }
}

if ($showprogress) {
  print "Edged Map:\n"; showmap(); delay();
}

my $obstacle  = ($arg{branch} eq 'swamp') ? watertile() : rocktile();
my $floorfreq = ($arg{branch} eq 'swamp') ? 85 : 60;
fillundecidedareas(1, 1, ($cols - 2), ($rows - 2),
                   [ $floorfreq, floortile() ],
                   [ 101,        $obstacle ],
                  );

if ($showprogress) {
  print "Decided Middle:\n"; showmap(); delay();
}

my $canwalk  = sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR/; };
my $canfly   = sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR|LAVA|WATER|POOL/; };
my $canswim  = sub { my ($tile) = @_; $$tile{TERRAIN} =~ /WATER|POOL/ };
my $canphase = ($arg{lair} ne 'none')
  ? sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR|ROCK|IRONBARS/; }
  : sub { my ($tile) = @_; $$tile{TERRAIN} =~ /FLOOR|DOOR|ROCK|IRONBARS|WALL/; };
fillconnect($upx, $upy, $canwalk,  'walkto<', 'diag');
fillconnect($dnx, $dny, $canwalk,  'walkto>', 'diag');
fillconnect($upx, $upy, $canfly,   'flyto<');
fillconnect($dnx, $dny, $canfly,   'flyto>');
fillconnect($upx, $upy, $canswim,  'swimto<');
fillconnect($dnx, $dny, $canswim,  'swimto>');
fillconnect($upx, $upy, $canphase, 'phaseto<', 'diag');
fillconnect($dnx, $dny, $canphase, 'phaseto>', 'diag');

my @trap = shuffle(
                   (['^', 'red',        'fire trap']) x 10,
                   (['^', 'bold black', 'pit']) x 10,
                   (['^', 'bold black', 'spiked pit']) x 5,
                   (['^', 'blue',       'anti-magic field']),
                   (['^', 'blue',       'magic trap']) x 3,
                  );
if ($arg{branch} eq 'swamp') {
  @trap = shuffle(
                  (['^', 'blue',   'rust trap']) x 3,
                  (['^', 'blue',   'sleeping gas trap']) x 4,
                  (['^', 'yellow', 'pit']) x 10,
                  (['^', 'yellow', 'spiked pit']) x 5,
                  (['^', 'blue',   'anti-magic field']) x 3,
                  (['^', 'blue',   'magic trap']) x 5,
                  (['`', 'white',  'statue trap']) x 2,
                  (['^', 'blue',   'polymorph trap']),
                 );
}
my @used = ();
my @placedtrap = ();
for (1 .. 6 + (int rand 5) + (int rand 5)
            + (int rand 5) + (int rand 5)
            + (int rand 5) + (int rand 5)) { # 6d5 traps
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

my (@flyingmonster, @seamonster, @othermonster);

if ($arg{branch} eq 'firepits') {
  @flyingmonster = shuffle(
                           (['e', 'red',    'flaming sphere']) x 2,
                           (['v', 'red',    'fire vortex']) x 2,
                           (['y', 'bold black',  'black light']),
                           (['D', 'red',    'red dragon']) x 2,
                           (['D', 'red',    'great red dragon']) x 2,
                           (['E', 'bold yellow', 'fire elemental']) x 3,
                          );
  @seamonster   = @flyingmonster;
  @othermonster = shuffle(
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
                          (['S', 'blue','pit viper']) x 2, # In the fire pits, ha ha ha.
                         );
} elsif ($arg{branch} eq 'swamp') {
  @flyingmonster = shuffle(
                           (['A', 'green',        'couatl']) x 14,
                           (['D', 'red',          'red dragon']),
                           (['D', 'green'    ,    'green dragon']) x 4,
                           (['D', 'green'    ,    'great green dragon']) x 3,
                           (['D', 'bold black',   'black dragon']),
                           (['D', 'bold black',   'great black dragon']),
                           (['D', 'blue',         'blue dragon']),
                           (['D', 'white',        'gray dragon']),
                           (['D', 'bold white',   'white dragon']),
                           (['D', 'bold yellow',  'yellow dragon']),
                           (['D', 'bold cyan',    'silver dragon']),
                           (['D', 'bold red',     'orange dragon']),
                           (['y', 'bold black',   'black light']) x 6,
                           (['y', 'bold yellow',  'yellow light']) x 3,
                           (['E', 'bold cyan',    'air elemental']) x 7,
                           (['g', 'magenta',      'winged gargoyle']) x 3,
                           (['h', 'magenta',      'mind flayer']) x 6,
                           (['h', 'magenta',      'master mind flayer']) x 12,
                           (['e', 'white',        'gas spore']) x 12,
                           (['V', 'blue',         'vampire lord']) x 12,
                           (['H', 'magenta',      'titan']),
                          );
  @seamonster = shuffle(
                        (['E', 'blue',         'water elemental']) x 6,
                        (['&', 'blue',         'water demon']) x 6,
                        (['T', 'blue',         'water troll']) x 6,
                        ([';', 'blue',         'jellyfish']) x 3,
                        ([';', 'red',          'piranha']) x 3,
                        ([';', 'white',        'shark']) x 4,
                        ([';', 'cyan',         'giant eel']) x 7,
                        ([';', 'bold blue',    'electric eel']) x 7,
                        ([';', 'red',          'kraken']) x 8,
                        (['N', 'red',          'red naga']) x 2,
                        (['N', 'bold yellow',  'golden naga']) x 3,
                        (['N', 'green',        'guardian naga']) x 3,
                        (['N', 'bold black',   'black naga']),
                       );
  @othermonster = shuffle(
                          (['S', 'green',        'garter snake']),
                          (['S', 'yellow',       'snake']) x 2,
                          (['S', 'yellow',       'water moccasin']) x 8,
                          (['S', 'blue',         'pit viper']),
                          (['S', 'magenta',      'python']) x 8,
                          (['S', 'blue',         'cobra']) x 2,
                          (['j', 'blue',         'blue jelly']) x 6,
                          (['j', 'green',        'spotted jelly']) x 6,
                          (['j', 'yellow',       'ochre jelly']) x 3,
                          (['O', 'yellow',       'ogre']), # ogres in swamps as a reference to Shrek
                          (['O', 'red',          'ogre lord']) x 2,
                          (['O', 'magenta',      'ogre king']) x 3,
                          (['P', 'bold green',   'green slime']) x 6,
                          (['R', 'blue',         'disenchanter']),
                          (['L', 'magenta',      'arch-lich']),
                          (['L', 'magenta',      'master lich']),
                          (['L', 'red',          'demilich']),
                          (['L', 'red',          'lich']),
                          (['F', 'red',          'red mold']),
                          (['F', 'magenta',      'violet fungus']) x 2,
                          (['F', 'magenta',      'shrieker']) x 2,
                          (['F', 'yellow',       'brown mold']) x 2,
                          (['F', 'green',        'green mold']),
                          (['F', 'bold yellow',  'yellow mold']),
                          (['F', 'bold green',   'lichen']),
                          ([':', 'red',          'crocodile']) x 3,
                          ([':', 'red',          'chameleon']) x 4,
                          (['g', 'green',        'gremlin']),
                          (['g', 'red',          'gargoyle']),
                          (['i', 'cyan',         'tengu']),
                          (['i', 'green',        'homunculus']),
                          (['i', 'blue',         'quasit']),
                          (['&', 'yellow',       'horned devil']),
                          (['&', 'white',        'incubus']),
                          (['&', 'white',        'succubus']),
                          (['&', 'red',          'barbed devil']),
                          (['&', 'red',          'maralith']),
                          (['&', 'red',          'vrock']),
                          (['&', 'white',        'bone devil']),
                          (['&', 'red',          'nalfeshnee']) x 5,
                          (['&', 'white',        'sandestin']) x 4,
                          (['&', 'red',          'pit fiend']),
                          (['&', 'red',          'balrog']) x 2,
                          (['w', 'magenta',      'purple worm']) x 2,
                          (['n', 'blue',         'water nymph']),
                          (['U', 'yellow',       'umber hulk']),
                         );
} else {
  warn "Unknown branch: $arg{branch}";
}

my @used = ();
if ($arg{lair} eq 'yeenoghu') {
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
  push @monster, qq[Yeenoghu (] . ($xoffset + $gx) . ',' . ($yoffset + $gy) . qq[)];
} elsif ($arg{lair} eq 'dis') {
  # Ambush!  All of these monsters would be set to wait until they have the
  #          player in line-of-sight and then attack immediately.  It should
  #          not matter if the player is invisible or not.
  my @place = shuffle([3, 3],   [7, 3],   [11, 3], [2, 8],   [6, 9],   [9, 9],
                      [17, 6],  [16, 12], [3, 12], [6, 16],  [10, 17], [14, 17],
                      [18, 16], [23, 16], [19, 9], [26, 10], [22, 3],  [25, 5],
                      [30, 4],  [26, 7],  [28, 10],);
  my @demon = shuffle(# Note: this array is assumed to be larger than @place.
                      (['&', 'yellow', 'horned devil']) x 2,
                      (['&', 'white', 'incubus']) x 2,
                      (['&', 'white', 'succubus']) x 2,
                      (['&', 'red', 'barbed devil']) x 2,
                      (['&', 'red', 'maralith']) x 2,
                      (['&', 'red', 'vrock']) x 2,
                      (['&', 'white', 'bone devil']) x 2,
                      (['&', 'red', 'nalfeshnee']) x 4,
                      (['&', 'red', 'pit fiend']) x 4,
                      (['&', 'red', 'balrog']) x 4,
                      ([':', 'red', 'salamander']) x 4,
                     );
  unshift @demon, ['&', 'magenta', 'Dispater'];
  for my $p (@place) {
    my $d = shift @demon;
    my ($x, $y) = @$p;
    my ($monglyph, $moncolor, $monname) = @$d;
    $map[$xoffset + $x][$yoffset + $y]{GLYPH} = $monglyph;
    $map[$xoffset + $x][$yoffset + $y]{COLOR} = $moncolor;
    push @monster, qq[$monname (] . ($xoffset + $x) . ',' . ($yoffset + $y) . qq[)];
  }
  my @cage  = shuffle([13, 3, 15, 4],   [11, 8, 12, 9],   [18, 11, 21, 11],
                      [25, 13, 27, 13], [19, 4, 20, 7],   [27, 2, 28, 2],
                      [9, 12, 9, 12],   [14, 13, 14, 13],
                     );
  my @cagemonst = shuffle((['D', 'red',    'red dragon']) x 2,
                          (['D', 'red',    'great red dragon']) x 2,
                          (['N', 'red',    'red naga']) x 3,
                          (['d', 'red',    'hell hound']) x 3,
                          (["'", 'cyan',   'iron golem']),
                         );
  for my $c (@cage) {
    for my $x ($$c[0] .. $$c[2]) {
      for my $y ($$c[1] .. $$c[3]) {
        if (rand(100) > 30) {
          my $monst = shift @cagemonst;
          my ($monglyph, $moncolor, $monname) = @$monst;
          $map[$xoffset + $x][$yoffset + $y]{GLYPH} = $monglyph;
          $map[$xoffset + $x][$yoffset + $y]{COLOR} = $moncolor;
          push @monster, qq[$monname (] . ($xoffset + $x) . ',' . ($yoffset + $y) . qq[)];
          push @cagemonst, $monst; # Recycle.
        }}}
  }
} elsif ($arg{lair} eq 'juiblex') {
  $map[$xoffset + 4][$yoffset + 3]{GLYPH} = '&';
  $map[$xoffset + 4][$yoffset + 3]{COLOR} = 'magenta';
  push @monster, qq[Juiblex (] . ($xoffset + 4) . ',' . ($yoffset + 3) . qq[)];
} elsif ($arg{lair} =~ /^asmo/) {
  push @monster, qq[Asmodeus (on >, not shown)];
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
    my ($monglyph, $moncolor, $monname, $transmode) = @$monster;
    $transmode ||= 'walk';
    if ($arg{lair} eq 'asmo1') {
      my $x = $xoffset + 7 + int rand 9;
      my $y = $yoffset + 4 + int rand 4;
    } else {
      my $x = $xoffset + 1 + int rand 9;
      my $y = $yoffset + 3 + int rand 4;
    }
    my $tries = 0;
    while (($tries++ < 20)
           and not $map[$x][$y]{GLYPH} =~ /[.]/) {
      $x = $xoffset + 7 + int rand 9;
      $y = $yoffset + 4 + int rand 4;
    }
    $map[$x][$y]{GLYPH} = $monglyph;
    $map[$x][$y]{COLOR} = $moncolor;
    my $getto     = '';
    $getto       .= "<" if $map[$x][$y]{CONNECT}{$transmode.'<'};
    $getto       .= ">" if $map[$x][$y]{CONNECT}{$transmode.'>'};
    $getto        = ",$getto" if $getto;
    push @monster, qq[$monname ($x,$y$getto)];
  }
}
my $otherwanted = 4 + (int rand 3) + (int rand 3)
                    + (int rand 3) + (int rand 3); # 4d3 land-based monsters
if ($arg{lair} =~ /^baal/) { # Extra xorns.
  @othermonster = ((['X', 'yellow', 'xorn']) x 3,
                   @othermonster);
  $otherwanted += 3;
}
for (1 .. $otherwanted) {
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

if ($arg{branch} eq 'swamp') {
  for (1 .. 8 + (int rand 3) + (int rand 3) # 8d3 sea monsters
       + (int rand 3) + (int rand 3) + (int rand 3)
       + (int rand 3) + (int rand 3) + (int rand 3)) {
    if (not scalar @seamonster) {
      @seamonster = shuffle(@used); @used = ();
    }
    my $monster = shift @seamonster;
    my ($monglyph, $moncolor, $monname) = @$monster;
    push @used, $monster;
    my $x = 2 + int rand($cols - 3);
    my $y = 1 + int rand($rows - 2);
    my $tries = 0;
    while (($tries < 1000)
           and (($map[$x][$y]{TERRAIN} ne 'WATER') or
                ($map[$x][$y]{GLYPH} ne '}'))) {
      $x = 2 + int rand($cols - 3);
      $y = 1 + int rand($rows - 2);
    }
    $map[$x][$y]{GLYPH} = $monglyph;
    $map[$x][$y]{COLOR} = $moncolor;
    my $getto = '';
    $getto   .= "<" if $map[$x][$y]{CONNECT}{'swimto<'};
    $getto   .= ">" if $map[$x][$y]{CONNECT}{'swimto>'};
    $getto    = ",$getto" if $getto;
    push @monster, qq[$monname ($x,$y$getto)];
  }
}

my $flyingwanted = 5 + (int rand 3) + (int rand 3)
                     + (int rand 3) + (int rand 3) + (int rand 3); # 5d3 flying monsters
if ($arg{branch} eq 'swamp') {
  $flyingwanted += 10 + (int rand 3) + int rand (3); # more.
  if ($arg{lair} eq 'demo') {
    $flyingwanted += 4;
    @flyingmonster = ((['e', 'white',        'gas spore']) x 4,
                      @flyingmonster);
  }
}

for (1 .. $flyingwanted) {
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
print "Branch: " . ($branchtitle{$arg{branch}} || $arg{branch} || '[default]')
  . (($arg{lair}) ? qq[, $lairtitle{$arg{lair}}] : '') . "\n";
print "Walkable: " . ($map[$upx][$upy]{CONNECT}{'walkto>'} ? 'yes'
                      : ('no' .
                         " (with digging: "
                         . ($map[$upx][$upy]{CONNECT}{'phaseto>'} ? 'yes)' : 'no)'))) ."\n";
print "Flyable: "  . ($map[$upx][$upy]{CONNECT}{'flyto>'}  ? 'yes' : 'no') . "\n";
print "Traps: " . (join ", ", @placedtrap) . "\n";
print "Monsters: " . (join ", ", @monster) . "\n";
print "\n";
exit 0; # Subroutines follow

sub delay {
  select undef, undef, undef, $arg{delay} if $arg{delay};
}

sub randomlair {
  my ($branch) = @_;
  my @lair;
  my $switch = rand(14897) % 5;
  if ($switch == 1) {
    if ($branch eq 'swamp') {
      @lair = ('juiblex');
    } else {
      @lair = ('asmo1', 'asmo2', 'baal');
    }
  } elsif ($switch == 3) {
    if ($branch eq 'swamp') {
      @lair = ('demo');
    } else {
      @lair = ('yeenoghu', 'dis');
    }
  } else {
    @lair = ('none');
  }
  return $lair[int rand @lair];
}

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
sub watertile {
  return +{ TERRAIN => 'WATER',
            GLYPH   => '}',
            COLOR   => 'bold cyan',
            BG      => 'on_blue',
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

sub fillundecidedareas {
  my ($minx, $miny, $maxx, $maxy, @terr) = @_;
  for my $x ($minx .. $maxx) {
    for my $y ($miny .. $maxy) {
      my $rnum = rand(100); my $tnum = 0;
      while ($rnum > $terr[$tnum][0]) { $tnum++; }
      my $newtile = $terr[$tnum][1];
      maybefill($x, $y, 'UNDECIDED', copytile($newtile));
      if ($map[$x][$y]{TERRAIN} eq 'LAVA') {
        $lavacount++;
      } elsif ($map[$x][$y]{TERRAIN} eq 'WATER') {
        $watercount++;
      } elsif (int rand(100) < int(50 + rand rand 15)) {
        $desiredlava-- if $desiredlava;
        $desiredwater-- if $desiredwater;
      }
    }
  }
}

sub embedrandompos {
  my (@e) = @_; # The embed is assumed to be rectangular.  (But, it can contain undecided terrain.)
  my $embedheight = scalar @e;
  my $embedwidth  = scalar @{$e[0]};
  my $x = 2 + int rand($cols - $embedwidth - 4);
  my $y = 1 + int rand($rows - $embedheight - 2);
  return ($x, $y);
}

sub embedcenter {
  my (@e) = @_; # The embed is assumed to be rectangular.  (But, it can contain undecided terrain.)
  my $x = int(($cols - scalar @{$e[0]}) / 2);
  my $y = int(($rows - scalar @e) / 2);
  return ($x, $y);
}

sub embedoverlap {
  my ($eone, $xone, $yone, $etwo, $xtwo, $ytwo, $xpadding, $ypadding) = @_;
  my $heightone = $ypadding + scalar @$eone;
  my $heighttwo = $ypadding + scalar @$etwo;
  my $widthone  = $xpadding + scalar @{$$eone[0]};
  my $widthtwo  = $xpadding + scalar @{$$etwo[0]};
  my ($xoverlap, $yoverlap);
  if ($xone > $xtwo) {
    $xoverlap = ($xtwo + $widthtwo >= $xone) ? 1 : 0;
  } else {
    $xoverlap = ($xone + $widthone >= $xtwo) ? 1 : 0;
  }
  if ($yone > $ytwo) {
    $yoverlap = ($ytwo + $heighttwo >= $yone) ? 1 : 0;
  } else {
    $yoverlap = ($yone + $heightone >= $ytwo) ? 1 : 0;
  }
  #warn "  (eone,$xone,$yone,etwo,$xtwo,$ytwo,$xpadding,$ypadding): [$xoverlap,$yoverlap]\n";
  return ($xoverlap and $yoverlap);
}

sub placeembed {
  my ($e, $xoffset, $yoffset) = @_;
  my $dy = 0;
  for my $line (@$e) {
    my $dx = 0;
    for my $tile (@$line) {
      $map[$xoffset + $dx][$yoffset + $dy] = copytile($tile);
      $dx++;
    }
    $dy++;
  }
  if ($showprogress) {
    print "Placed Embed: \n"; showmap(); delay();
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
      } elsif ($char eq 'W') {
        $$tile{TERRAIN} = 'WATER';
        $$tile{COLOR}   = 'bold cyan';
        $$tile{BG}      = 'on_blue';
        $$tile{GLYPH}   = '}';
      } elsif ($char eq 'P') {
        $$tile{TERRAIN} = 'POOL';
        $$tile{COLOR}   = 'bold cyan';
        $$tile{BG}      = 'on_black';
        $$tile{GLYPH}   = '}';
      } elsif ($char eq '#') {
        $$tile{TERRAIN} = 'IRONBARS';
        $$tile{COLOR}   = 'cyan';
        $$tile{BG}      = 'on_black';
        $$tile{GLYPH}   = '#';
      }
      $tile;
    } split //, $_]
  } @_;
}
