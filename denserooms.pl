#!/usr/bin/perl
# -*- cperl -*-

# This is a Perl program that generates the following
# proposed new types of NetHack level styles:
# 1. levels consisting mostly of densely packed rooms of
#    varying sizes, per Benjamin Schmit's suggestion
# 2. levels containing rectangular rooms that may overlap,
#    resulting in extra walls partitioning them into sections
# 3. levels containing possibly non-rectangular rooms
#    (L-shaped, T-shaped, U-shaped, cross-shaped, etc.)
# 4. fractally generated maps consisting of rock, corridor,
#    floor, and either water or lava in the lowest areas
# Layout styles 1-3 also get corridors, which are generated
# in one of four ways:
# 1. Haphazard - corridors can leave a room in any direction
# 2. Systematic - corridors try to leave each room in each
#                 direction (except at the level edges)
# 3. Directed - corridors are aimed from one room to another
# 4. Hybrid - a mixture of the above styles
# 5. None - no corridors are generated

# In some cases portions of the level rock may also be
# "dug out" ahead of time.

# This is all strictly experimental, and of course this Perl
# code will not integrate into NetHack, so in order to be
# used it would need to be reimplemented in C and integrated
# into NetHack's existing level-generation code.

# If implemented, these types of levels could be used in
# custom dungeon content, in special levels (e.g., quest
# filler levels for proposed new roles), and potentially
# in Gehennom to replace some of the maze levels.

# Note that these levels should NOT be used very early in
# the dungeons, because they may contain disconnected areas
# that can only be reached by digging or teleport, as well
# as water and/or lava that may need to be traversed in some
# cases.  Also, the special rooms contain monsters that a
# pre-quest, pre-castle character should not have to face.
# In other words, these are strictly late-game levels.

# Don't worry if the choices of monsters seem odd.  Except
# for special rooms, this script does not attempt realistic
# monster generation, because the intention is that the
# existing monster generation code be used.  So while this
# script does pepper the levels with random monsters, that's
# just so they don't look totally bare.

# Other than that, there are still a few bugs to work out
# but I think it's reached the point where it's worth
# soliciting feedback...

# If the idea of new kinds of levels to mix in with the
# mazes in Gehennom interests you, please run this Perl
# script a few times and let me know what you think.
# Specific suggestions are welcome.

use strict;
my %arg = @ARGV;

my $debug         = $arg{debug}         || 3;
my $layoutstyle   = $arg{layoutstyle}   || 1 + int rand 4;
my $corridorstyle = $arg{corridorstyle} || 1 + irr(5);
my $maxrows       = $arg{maxrows}       || 24;
my $maxcols       = $arg{maxcols}       || 65 + int rand(4);
my $maxroomwidth  = $arg{maxroomwidth}  || int($maxcols *
                                               (0.2 + rand 0.25));
my $maxroomheight = $arg{maxroomheight} || int($maxrows *
                                               (0.15 + rand 0.15));
my $minroomwidth  = $arg{minroomwidth}  || 2;#  + int rand(2);
my $minroomheight = $arg{minroomheight} || 2;#  + int rand(1);
my $secretprob    = $arg{secretprob}    || 30;
my $blankchar     = $arg{blankchar}     || ' ';
my $corridorchar  = $arg{corridorchar}  || '#';
my $percentdugout = $arg{percentdugout} || (irr(100)<30)?0:irr(90);
my $dugchar       = $arg{dugchar}       || $corridorchar;
my $dugcolor      = $arg{dugcolor}      || 'white';
my $floorchar     = $arg{floorchar}     || '.';
my $horizwallchar = $arg{horizwallchar} || '-';
my $vertwallchar  = $arg{vertwallchar}  || '|';
my $doorchar      = $arg{doorchar}      || '+';
my $sdoorchar     = $arg{sdoorchar}     || '+';
my $nwcornerchar  = $arg{nwcornerchar}  || '/';
my $necornerchar  = $arg{necornerchar}  || "\\";
my $swcornerchar  = $arg{swcornerchar}  || "\\";
my $secornerchar  = $arg{secornerchar}  || '/';
my $errorchar     = $arg{errorchar}     || 'E';
my $errorcolor    = $arg{errorcolor}    || 'bold yellow on_red';
# The next two are NOT lexical, so that they can be dynamic
# (to make certain things easier to see while tweaking).
our   $wallcolor     = $arg{wallcolor}     || 'white on_black';
our   $floorcolor    = $arg{floorcolor}    || 'reset';
my $doorcolor     = $arg{doorcolor}     || 'yellow on_black';
my $sdoorcolor    = $arg{sdoorcolor}    || $wallcolor;
my $corridorcolor = $arg{corridorcolor} || 'reset';
my $corridorfreq  = $arg{corridorfreq}  || 2 + int rand 2;
my $corridortwist = $arg{corridortwist} || 6 + irr(12);
my $corridorcross = $arg{corridorcross} || 35 + rand 30;
my $allcorridors  = $arg{allcorridors}  || 1;
my $jaggedcorr    = $arg{jaggedcorr}    || 10 + rand 80;
my $maxcorrlength = $arg{maxcorrlength} || $maxrows + $maxcols*1.5;
my $connectretry  = $arg{connectretry}  || 3;
my $fountainprob  = $arg{fountainprob}  || 7;
my $maxfountains  = $arg{maxfountains}  || 8;
my $maxroomfounts = $arg{maxroomfounts} || 4;
my $staircolor    = $arg{staircolor}    || 'bold white';
my $upstaircolor  = $arg{upstaircolor}  || $staircolor;
my $downstaircolor= $arg{downstaircolor}|| $staircolor;
my $fountainchar  = $arg{fountainchar}  || '{';
my $fountaincolor = $arg{fountaincolor} || 'bold blue';
my $sinkprob      = $arg{sinkprob}      || 5;
my $maxsinks      = $arg{maxsinks}      || 6;
my $maxroomsinks  = $arg{maxroomsinks}  || 1;
my $sinkchar      = $arg{sinkchar}      || '#';
my $sinkcolor     = $arg{sinkcolor}     || 'bold cyan';
my $altarprob     = $arg{altarprob}     || 3;
my $maxaltars     = $arg{maxaltars}     || 2;
my $priestprob    = $arg{priestprob}    || 30;
my $altarchar     = $arg{altarchar}     || '_';
my $altarcolor    = $arg{altarcolor}    || 'bold yellow';
my $priestchar    = $arg{priestchar}    || '@';
my $priestcolor   = $arg{priestcolor}   || 'bold white';
my $graveprob     = $arg{graveprob}     || 5;
my $maxgraves     = $arg{maxgraves}     || 3;
my $gravechar     = $arg{gravechar}     || '|';
my $gravecolor    = $arg{gravecolor}    || 'bold white on_black';
my $poolprob      = $arg{poolprob}      || 7;
my $morepoolprob  = $arg{morepoolprob}  || 65;
my $maxpools      = $arg{maxpools}      || 15;
my $maxroompools  = $arg{maxroompools}  || 9;
my $poolchar      = $arg{poolchar}      || '}';
my $poolcolor     = $arg{poolcolor}     || 'bold cyan on_blue';
my $lavaprob      = $arg{lavaprob}      || 12;
my $morelavaprob  = $arg{morelavaprob}  || 85;
my $maxlava       = $arg{maxlava}       || 9;
my $maxroomlava   = $arg{maxroomlava}   || 9;
my $lavachar      = $arg{lavachar}      || '}';
my $lavacolor     = $arg{lavacolor}     || 'bold red';
my $specialprob   = $arg{specialprob}   || 7;
my $statuechar    = $arg{statuechar}    || "`";
my $statuecolor   = $arg{statuecolor}   || 'reset';
my $statuespacing = $arg{statuespacing} || undef;
my $monsterprob   = $arg{monsterprob}   || 45;
my $mongroupprob  = $arg{mongroupprob}  || 5;
my $moremonstprob = $arg{moremonstprob} || 75;
my $maxgroupsize  = $arg{maxgroupsize}  || 9;
my $maxroommonst  = $arg{maxroommonst}  || 11;
my $widthdivisor  = $arg{widthdivisor}  || 2;
my $heightdivisor = $arg{heightdivisor} || 2;
my $fractalvaries = $arg{fractalvaries} || rand(5);
my $fractaljitter = $arg{fractaljitter} || rand(3);
my $liquidthresh  = $arg{liquidthresh}  || 2 + rand(2);
my $floorthresh   = $arg{floorthresh}   || 12 + rand(6);
my $corridorthresh= $arg{corridorthresh}|| 16 + rand(8);

my $roomnum      = 0;
my $jotcount     = 0;
my @room;

my %layoutname = (
                  1 => 'Dense Room Packing',
                  2 => 'Overlapping Rectangles',
                  3 => 'Non-Rectangular Rooms',
                  4 => 'Plasma Fractal',
                 );
my %corrname = (
                1 => 'Haphazard',
                2 => 'Systematic',
                3 => 'Directed',
                4 => 'Hybrid',
                5 => 'None',
               );

my @randcolor = ('cyan', 'blue', 'green', 'red', 'magenta',
                 'bold black', 'bold cyan', 'bold blue',
                 'bold green', 'bold red', 'bold yellow',
                 'bold magenta', 'bold white'
                );

my @randmonst = (
                 # This list is not intended to accurately
                 # reflect what would actually happen in
                 # the game.  It's just a sampling so the
                 # levels can look approximately normal.
                 # (The proposed dense-room-and-corridor
                 # levels, if implemented, would use the
                 # existing random monster generation code.)
                 ['water demon', '&', 'blue'],
                 ['horned devil', '&', 'bold red'],
                 ['succubus', '&', 'reset'],
                 ['incubus', '&', 'reset'],
                 ['barbed devil', '&', 'red'],
                 ['vrock', '&', 'red'],
                 ['hezrou', '&', 'red'],
                 ['bone devil', '&', 'white'],
                 ['ice devil', '&', 'bold white'],
                 ['nalfeshnee', '&', 'red'],
                 ['pit fiend', '&', 'red'],
                 ['balrog', '&', 'red'],
                 ['fire ant', 'a', 'red'],
                 ['hell hound', 'd', 'red'],
                 ['tiger', 'f', 'bold yellow'],
                 ['gremlin', 'g', 'green'],
                 ['gargoyle', 'g', 'yellow'],
                 ['winged gargoyle', 'g', 'magenta'],
                 ['mind flayer', 'h', 'bold magenta'],
                 ['ochre jelly', 'j', 'yellow'],
                 ['giant mimic', 'm', 'magenta'],
                 ['mountain nymph', 'n', 'yellow'],
                 ['Uruk-hai', 'o', 'bold black'],
                 ['orc-captain', 'o', 'magenta'],
                 ['wumpus', 'q', 'cyan'],
                 ['titanothere', 'q', 'reset'],
                 ['mastodon', 'q', 'bold black'],
                 ['trapper', 't', 'green'],
                 ['purple worm', 'w', 'bold magenta'],
                 ['xan', 'x', 'red'],
                 ['zruty', 'z', 'yellow'],
                 ['vampire bat', 'B', 'bold black'],
                 ['stalker', 'E', 'bold white'],
                 ['air elemental', 'E', 'bold cyan'],
                 ['fire elemental', 'E', 'bold yellow'],
                 ['earth elemental', 'E', 'yellow'],
                 ['water elemental', 'E', 'bold blue'],
                 ['shrieker', 'F', 'bold magenta'],
                 ['titan', 'H', 'bold magenta'],
                 ['storm giant', 'H', 'bold blue'],
                 ['jabberwock', 'J', 'bold red'],
                 ['arch-lich', 'L', 'bold magenta'],
                 ['demilich', 'L', 'red'],
                 ['golden naga', 'N', 'bold yellow'],
                 ['ogre king', 'O', 'magenta'],
                 ['green slime', 'P', 'bold green'],
                 ['disenchanter', 'R', 'blue'],
                 ['Olog-hai', 'T', 'bold magenta'],
                 ['umber hulk', 'U', 'yellow'],
                 ['wraith', 'W', 'bold black'],
                 ['xorn', 'X', 'yellow'],
                 ['sasquatch', 'Y', 'reset'],
                 ['iron golem', "'", 'cyan'],
                 ['ghost', ' ', 'bold black'],
                );

  my %connectible = (
                     floor => 1, stairs   => 1, lava => 1,
                     altar => 1, statue   => 1, pool => 1,
                     grave => 1, fountain => 1, sink => 1,
                     tree  => 1,
                    );

$|=1;

use Term::ANSIColor;
use Carp;

my @pos = map {
  my $y = $_ - 1;
  [ map {
    my $x = $_ - 1;
    my $dug = (rand(100)<=$percentdugout) ? 1 : 0;
    +{
      posy => $y,
      posx => $x,
      char => $dug ? $dugchar : $blankchar,
      room => undef,
      terr => $dug ? 'dug (by default)' : 'rock (by default)',
      colr => $dug ? $dugcolor : 'reset',
      furn => [],
      objs => [],
      mons => undef,
     };
  } 1 .. $maxcols ];
} 1 .. $maxrows;

print "Using layout style $layoutstyle.\n";

if ($layoutstyle == 1) {
  layout_dense_rooms();
} elsif ($layoutstyle == 2) {
  layout_overlapping_rooms();
} elsif ($layoutstyle == 3) {
  layout_non_rectangular_rooms();
} elsif ($layoutstyle == 4) {
  layout_plasma_fractal();
  $corridorstyle = 100;
} else {
  die "Unknown layout style: $layoutstyle";
}

# Put stuff in the rooms...

my ($didup, $diddown) = (0, 0);
my ($fountcount, $sinkcount, $altarcount, $gravecount,
    $poolcount, $lavacount) = (0, 0, 0, 0, 0, 0);
for my $room (map { $$_[0]
                  } sort { $$a[1] <=> $$b[1]
                  } map {  [$_, rand(953)]
                  } @room) {
  jot($_) for split //, " R$$room{room}";
  my ($roomfountcount, $roomsinkcount,
      $roompoolcount, $roomlavacount) = (0, 0, 0, 0);
  my $special;
  if (not $didup) {
    $didup = placefurniture($room, 'stairs',
                            '<', $upstaircolor);
    jot("<") if $debug > 5;
  } elsif (not $diddown) {
    $diddown = placefurniture($room, 'stairs',
                              '>', $downstaircolor);
    jot(">") if $debug > 5;
  } else {
    if (rand(100)<=$specialprob) {
      $special = 'statue hall'; # Default
      jot("S") if $debug > 5;
      if (rand(100)<=40) {
        $special = 'dragon lair';
        jot("D") if $debug > 6;
      } elsif (rand(100)<=50) {
        $special = 'garden of temptation';
        jot("G") if $debug > 6;
      } # TODO: more special-room options
    }}
  if ($special eq 'statue hall') {
    my @bordertile;
    my $statuecount;
    push @bordertile, $_ for map {
      my $x = $_;
      [$$room{starty}, $x]
    } $$room{startx} .. $$room{stopx};
    push @bordertile, $_ for map {
      my $y = $_;
      [$y, $$room{stopx}]
    } (($$room{starty} + 1) .. ($$room{stopy} - 1));
    push @bordertile, $_ for map {
      my $x = $_;
      [$$room{stopy}, $x]
    } reverse ($$room{startx} .. $$room{stopx});
    push @bordertile, $_ for map {
      my $y = $_;
      [$y, $$room{startx}]
    } reverse (($$room{starty} + 1) .. ($$room{stopy} - 1));
    my $spacing = (defined $statuespacing)
      ? $statuespacing : ((int rand(5)) ? 1 : rand(3));
    while (scalar @bordertile) {
      my $tile = shift @bordertile;
      placefurniture($room, 'statue', $statuechar,
                     $statuecolor, @$tile);
      for (1 .. $spacing) {
        shift @bordertile if scalar @bordertile;
      }}
    # TODO: also place some traps in the room.
  } elsif ($special eq 'dragon lair') {
    my %dragoncolor = (black => 'bold black',
                       red   => 'bold red',
                       blue  => 'blue',
                       gray  => 'white');
    my @color = keys %dragoncolor;
    my $color = $color[rand @color];
    placemonster($room, "great $color dragon",
                 'D', $dragoncolor{$color});
    placemonster($room, "$color dragon",
                 'D', $dragoncolor{$color})
      for 1 .. (2 + int rand 3);
    placemonster($room, "baby $color dragon",
                 'D', $dragoncolor{$color})
      for 1 .. (3 + int rand 4);
    # TODO: place gold and gems and thematic stuff
    #} elsif ($special eq 'another option') { # TODO
  } elsif ($special eq 'garden of temptation') {
    my @gmonst = (
                  ['succubus', '&', 'reset'],
                  ['incubus', '&', 'reset'],
                  ['mountain nymph', 'n', 'yellow'],
                  ['water nymph', 'n', 'blue'],
                  ['wood nymph', 'n', 'green'],
                 );
    my @gfurn = (
                 ['tree', '#', 'green'],
                 ['tree', '#', 'green'],
                 ['fountain', $fountainchar, $fountaincolor],
                 ['pool', $poolchar, $poolcolor],
                );
    for (1 .. 4) {
      my $f = $gfurn[rand @gfurn];
      my $m = $gmonst[rand @gmonst];
      placefurniture($room, @$f);
      placemonster($room, @$m);
      placemonster($room, @$m);
    }
  } else {
    jot("R") if $debug > 5;
    while ((rand(100) <= $fountainprob) and
           ($fountcount < $maxfountains) and
           ($roomfountcount < $maxroomfounts)) {
      if (placefurniture($room, 'fountain',
                         $fountainchar, $fountaincolor)) {
        $fountcount++; $roomfountcount++;
        jot($fountainchar) if $debug > 6;
      }}
    while ((rand(100) <= $sinkprob) and
           ($sinkcount < $maxsinks) and
           ($roomsinkcount < $maxroomsinks)) {
      if (placefurniture($room, 'sink',
                         $sinkchar, $sinkcolor)) {
        $sinkcount++; $roomsinkcount++;
        jot($sinkchar) if $debug > 6;
      }}
    if ((rand(100) <= $altarprob) and
        ($altarcount < $maxaltars)) {
      if (placefurniture($room, 'altar',
                         $altarchar, $altarcolor)) {
        $altarcount++;
        jot($altarchar) if $debug > 6;
        if (rand(100) <= $priestprob) {
          placemonster($room, 'aligned priest',
                       $priestchar, $priestcolor);
          jot($priestchar) if $debug > 6;
        }}}
    if ((rand(100) <= $graveprob) and
        ($gravecount < $maxgraves)) {
      if (placefurniture($room, 'grave',
                         $gravechar, $gravecolor)) {
        $gravecount++;
        jot($gravechar) if $debug > 6;
      }}
    # Terrain Features:
    while ((rand(100) <= ($roompoolcount
                          ? $morepoolprob
                          : $poolprob))
           and ($poolcount < $maxpools)
           and ($roompoolcount < $maxroompools)) {
      if (placefurniture($room, 'pool',
                         $poolchar, $poolcolor)) {
        $poolcount++; $roompoolcount++;
        jot($poolchar) if $debug > 6;
      }}
    while ((rand(100) <= ($roomlavacount
                          ? $morelavaprob
                          : $lavaprob))
           and ($lavacount < $maxlava)
           and ($roomlavacount < $maxroomlava)
           and (not $roompoolcount)
           and (not $roomfountcount)
           and (not $roomsinkcount)) {
      if (placefurniture($room, 'lava',
                         $lavachar, $lavacolor)) {
        $lavacount++; $roomlavacount++;
        jot($lavachar) if $debug > 6;
      }}
    my $roommonstcount = 0;
    while (rand(100) <= ($roommonstcount
                         ? $moremonstprob
                         : $monsterprob)) {
      my ($mtype, $mchar, $mcolor)
        = @{$randmonst[int rand @randmonst]};
      if (placemonster($room, $mtype, $mchar, $mcolor)) {
        $roommonstcount++;
        jot($mchar) if $debug > 6;
      }
      if (rand(100)<= $mongroupprob) {
        for (1 .. int rand $maxgroupsize) {
          if ($roommonstcount <= $maxroommonst) {
            if (placemonster($room, $mtype, $mchar, $mcolor)) {
              $roommonstcount++;
              jot("+") if $debug > 6;
            }
          }}}
    }
    # TODO: Place Objects
  }
}
print "\nPlacing corridors (style $corridorstyle)...\n" if $debug;

place_corridors();

printlevel();
exit 0; # ---------------- Subroutines follow --------------------

sub place_corridors {
  if ($corridorstyle == 1) {
    place_haphazard_corridors();
  } elsif ($corridorstyle == 2) {
    place_systematic_corridors();
  } elsif ($corridorstyle == 3) {
    place_directed_corridors();
  } elsif ($corridorstyle == 4) {
    place_hybrid_corridors();
  }
}

sub zeroorjag {
  if ($jaggedcorr) {
    return (rand(100)<25)
               ? rand(0.4)
               : 0;
  } else {
    return 0;
  }
}

sub place_systematic_corridors {
  my %conn;
  my @corrpos = sort {
    $$a[3] <=> $$b[3]
  } map {
    my $r = $_; map {
      my $coord = $_;
      my ($yd, $xd) = @$coord;
        [$r, $yd, $xd, rand(17)];
    } [-1, zeroorjag()],
      [ 1, zeroorjag()],
      [zeroorjag(), -1],
      [zeroorjag(),  1],
  } @room;
  my %corrconn;
  while (($allcorridors > 0) and
         (not all_rooms_connected(\@room, \%conn))) {
    for my $cp (@corrpos) {
      my $cwanted = $corridorfreq;
      #$cwanted = int($cwanted * 1.75) if $layoutstyle == 2;
      $cwanted = 1 + int rand (int(($cwanted + 3) / 4));
      my ($room, $ydir, $xdir) = @$cp;
      $cwanted = 0 if ($$room{startx} < 2 and $xdir < 0);
      $cwanted = 0 if ($$room{starty} < 2 and $ydir < 0);
      $cwanted = 0 if ($$room{stopx} + 2 >= $maxcols
                       and $xdir > 0);
      $cwanted = 0 if ($$room{stopy} + 2 >= $maxrows
                       and $ydir > 0);
      jot($_) for split //, " R$$room{room}<$ydir,$xdir>"
        . "CW$cwanted ";
      my (@conn, $attempt);
      while (($cwanted > scalar @conn) and ($attempt < 3)) {
        jot("-"); jot($_) for split //, $attempt;
        my $corridorlength = 0;
        my $secret = (rand(100) <= $secretprob) ? 1 : 0;
        my $connected = 0;
        my ($y, $x, $realy, $realx) = point_within_room($room);
        if ($debug > 7) {
          $pos[$y][$x]{colr} = 'bold cyan';
          $pos[$y][$x]{char} = ($$room{room} % 10);
        }
        while ($pos[$y][$x]{room} == $$room{room}) {
          if ($pos[$y][$x]{terr} eq 'floor') {
            jot($floorchar);
          } elsif ($pos[$y][$x]{terr} eq 'wall') {
            $pos[$y][$x]{terr} = 'door';
            $pos[$y][$x]{char} = $secret?$sdoorchar: $doorchar;
            $pos[$y][$x]{colr} = $secret?$sdoorcolor: $doorcolor;
            jot($doorchar);
          } elsif ($pos[$y][$x]{terr} eq 'door') {
            jot($doorchar);
          } else {
            $pos[$y][$x]{terr} = 'hall';
            $pos[$y][$x]{char} = $corridorchar;
            $pos[$y][$x]{colr} = $corridorcolor;
            jot($corridorchar);
          }
          $realx += $xdir; $x = int $realx;
          $realy += $ydir; $y = int $realy;
        } # That just gets us out of our starting room.
        # Now we can build the corridor until it connects
        # to something somewhere...
        while (not $connected) {
          my $loopcount = 0;
          $corrconn{$y}{$x}{$$room{room}} = 1;
          if ($pos[$y][$x]{terr} eq 'wall') {
            $pos[$y][$x]{terr} = 'door';
            $pos[$y][$x]{char} = $secret?$sdoorchar: $doorchar;
            $pos[$y][$x]{colr} = $secret?$sdoorcolor: $doorcolor;
            jot($doorchar);
          } elsif ($pos[$y][$x]{terr} eq 'door') {
            jot($doorchar);
          } elsif ($connectible{$pos[$y][$x]{terr}}) {
            jot($floorchar);
            if ($pos[$y][$x]{room} and
                ($pos[$y][$x]{room} ne $$room{room})) {
              $connected = 1; $attempt = 0;
              push @conn, $pos[$y][$x]{room};
              $conn{$pos[$y][$x]{room}}{$$room{room}}++;
              $conn{$$room{room}}{$pos[$y][$x]{room}}++;
              use Data::Dumper; print Dumper(\%conn)
                if $debug > 9;
              jot($_) for split //, "C$pos[$y][$x]{room}";
              printlevel() if $debug > 15;
              if (all_rooms_connected(\@room, \%conn)) {
                jot("A");
                return if rand(15) < $corridorfreq;
              }
            }
          } elsif ($pos[$y][$x]{terr} eq 'hall') {
            jot($corridorchar);
            my @targ = grep {
              not $conn{$_}{$$room{room}}
                and not ($_ == $$room{room})
              } keys %{$corrconn{$y}{$x}};
            if (@targ) {
              jot($_), split //, "c:" . (join ",", @targ);
              if (rand(100) >= $corridorcross) {
                $connected = scalar @targ;
                $attempt = 0;
                jot("s"); # stop here
              } else {
                jot("c"); # continue
              }
              push @conn, $_ for @targ;
              $conn{$_}{$$room{room}}++ for @targ;
              $conn{$$room{room}}{$_}++ for @targ;
              use Data::Dumper; print Dumper(\%conn)
                if $debug > 9;
            }
          } elsif ($pos[$y][$x]{terr} =~ /rock|default/) {
            jot("#") if $debug > 8;
            $pos[$y][$x]{terr} = 'hall';
            $pos[$y][$x]{char} = ($debug > 12)
                                 ? ("" . $corridorlength % 10)
                                 : $corridorchar;
            $pos[$y][$x]{colr} = $corridorcolor;
          } else {
            warn "Unhandled terrain type: '$pos[$y][$x]{terr}'";
            $connected = 1;
            $attempt++;
            push @conn, 'Error' if (not $attempt % 2);
          }
          my $turning = 0;
          my ($oldxdir, $oldydir);
          if (((rand(100) <= $corridortwist)
               and $corridorlength) or
              (($pos[$y][$x]{terr} =~ /wall|door/) and
               ($pos[$y+$ydir][$x+$xdir]{terr} =~ /wall|door/))) {
            ($oldxdir, $oldydir) = ($xdir, $ydir);
            $xdir = int rand(3) - 1;
            $ydir = int rand(3) - 1;
            if (($xdir ne $oldxdir) or ($ydir ne $oldydir)) {
              $pos[$y][$x]{colr} = 'bold yellow' if $debug > 9;
              jot("T") if $debug > 7;
              $turning = 1;
            }
          }
          while ((($x + $xdir < 0) or
                  ($x + $xdir >= $maxcols) or
                  ($y + $ydir < 0) or
                  ($y + $ydir >= $maxrows) or
                  #($pos[$y + $ydir][$x + $xdir]{crnr}) or
                  (($xdir == 0) and ($ydir == 0)) or
                  (($oldxdir + $xdir == 0) and
                   ($oldydir + $ydir == 0))
                 ) and ($loopcount++ < 1000)) {
            if ((($x + $xdir < 0) or
                 ($x + $xdir >= $maxcols) or
                 ($y + $ydir < 0) or
                 ($y + $ydir >= $maxrows)
                 # or ($pos[$y + $ydir][$x + $xdir]{crnr})
                ) and not $turning) {
              $pos[$y][$x]{colr} = 'bold magenta' if $debug > 9;
              jot("X") if $debug > 7;
            }
            $xdir = int rand(3) - 1;
            $ydir = int rand(3) - 1;
            $xdir = 1 if $x < 1;
            $ydir = 1 if $y < 1;
            $xdir = -1 if $x + 1 >= $maxcols;
            $ydir = -1 if $y + 1 >= $maxrows;
            if (rand(100) < $jaggedcorr) {
              if (rand(100) < 50) {
                $ydir *= (0.5 + (0.5 * rand(1)));
              } else {
                $xdir *= (0.5 + (0.5 * rand(1)));
              }}
          }
          warn "!" if ($loopcount >= 1000 and $debug > 2);
          $xdir *= -1 if (($x + $xdir < 0) or
                          ($x + $xdir >= $maxcols));
          $ydir *= -1 if (($y + $ydir < 0) or
                          ($y + $ydir >= $maxrows));
          if ($xdir and $ydir) {
            # When doing diagonals, attempt to fill in
            # an adjascent tile, to reduce the need for
            # squeezing through tight spaces:
            if (rand(100)<=60) {
              # Try for an adjacent tile horizontally:
              if ($pos[$y + int $ydir][$x]{char} eq $blankchar) {
                $pos[$y + int $ydir][$x]{terr} = 'hall';
                $pos[$y + int $ydir][$x]{char} = $corridorchar;
                $pos[$y + int $ydir][$x]{colr} =
                  ($debug > 9) ? 'red' : $corridorcolor;
              }
            } else {
              # Try for an adjacent tile vertically:
              if ($pos[$y][$x + int $xdir]{char} eq $blankchar) {
                $pos[$y][$x + int $xdir]{terr} = 'hall';
                $pos[$y][$x + int $xdir]{char} = $corridorchar;
                $pos[$y][$x + int $xdir]{colr} =
                  ($debug > 9) ? 'green' : $corridorcolor;
              }}
          }
          if (($y + $ydir > $maxrows) or ($y + $ydir < 0)) {
            $ydir *= -1;
          }
          if (($x + $xdir > $maxcols) or ($x + $xdir < 0)) {
            $xdir *= -1;
          }
          $x += $xdir;
          $y += $ydir;
          $corridorlength++ if ($xdir or $ydir);
          jot("*") if $debug > 8;
          if ($corridorlength > $maxcorrlength) {
            $attempt++;
            $connected = 1;
            push @conn, 'maxl' if not $attempt % 2;
          }
        }
      }}
    jot($_) for split //, "AC:$allcorridors";
    printlevel() if $debug > 4;
    $allcorridors -= 1;
  }
}

sub all_rooms_connected {
  my ($roomlist, $conn) = @_;
  defined $conn
    or croak "all_rooms_connected called without conn";
  my (@room) = map { $$_{room} } @$roomlist;
  use Data::Dumper; print Dumper(+{
                                   conn => $conn,
                                   numofrooms => (scalar @room),
                                  }) if $debug > 18;
  for my $iter (@room) {
    for my $roomone (@room) {
      for my $roomtwo (@room) {
        if ($$conn{$roomone}{$roomtwo}) {
          for my $r (keys %{$$conn{$roomone}}) {
            $$conn{$r}{$roomtwo} = 1;
            $$conn{$roomtwo}{$r} = 1;
          }}
      }}}
  use Data::Dumper; print Dumper(+{ conn => $conn
                                  }) if $debug > 16;
  # So now each should be marked as connected to every
  # other room that it's (even indirectly) connected to.
  # Thus we can just pick one and check whether it's
  # connected to all the others...
  my $testroom = shift @room;
  for my $target (@room) {
    return if not $$conn{$testroom}{$target};
  }
  jot($_) for split //, 'DONE';
  return 'All Connected';
}

sub place_hybrid_corridors {
  my @rm = grep { rand(100) <= 40 } @room;
  while (@rm) {
    my $roomone = shift @rm;
    if (@rm) {
      my $roomtwo = shift @rm;
      jot($_) for split //, qq[{$$roomone{room}-$$roomtwo{room}}];
      draw_corridor_between_rooms($roomone, $roomtwo);
    }}
  my %conn;
  my %corrconn;
  my %triedroom;
  while (($allcorridors > 0) and
         (not all_rooms_connected(\@room, \%conn))) {
    if ($debug > 4) {
      print "\nAllCorridors: $allcorridors\n";
      print "\nConnections:\n" . (join "", map {
        my $r = $room[$_];
        "  $$r{room} [$triedroom{$$r{room}}] "
          . "($$r{starty},$$r{startx}),"
          . "($$r{stopy},$$r{stopx}) => [" . (join ", ",
          keys %{$conn{$$r{room}}}) . "]\n";
      } 0 .. $#room) . "\n";
      #use Data::Dumper; print Dumper(+{ conn => \%conn,
      #                                  allc => $allcorridors,
      #                                });
      printlevel();
    }
    for my $room (map { $$_[0]
                      } sort { $$a[1] <=> $$b[1]
                             } map {  [$_, rand(953)]
                                    } @room) {
      my (@conn, %conn, $attempt);
      $triedroom{$$room{room}}++;
      my $cwanted = 1 + int rand $corridorfreq;
      $cwanted = int($cwanted * 1.75) if $layoutstyle == 2;
      if ($debug > 10) {
        printlevel();
      }
      jot($_) for split //, " R$$room{room}CW$cwanted ";
      while (($cwanted > scalar @conn) and ($attempt < 25)) {
        jot("-");
        my ($xdir, $ydir, $origin) = (0, 0, +{});
        my $secret = (rand(100) <= $secretprob) ? 1 : 0;
        my @save = @pos;
        my $originok = 0;
        my ($origindir, $origintry);
        my ($floorwidth, $floorheight);
        while ((not $originok) and ($origintry++ < 80)) {
          while (($xdir == 0) and ($ydir == 0)) {
            $xdir = (int rand(3)) - 1;
            $ydir = (int rand(3)) - 1;
          }
          $origindir =
            (not $xdir)
              ? 'vert'
              : (not $ydir)
                ? 'horz'
                : (rand(100) >= 50) ? 'vert' : 'horz';
          if ($origindir eq 'vert') {
            jot("V") if $debug > 6;
            # origin must be top or bottom
            jot(($ydir>0) ? "n" : "s") if $debug > 7;
            $$origin{y} = ($ydir > 0)
              ? $$room{stopy} + 1
              : $$room{starty} - 1;
            $floorwidth = $$room{stopx} - $$room{startx} + 1;
            $$origin{x} = $$room{startx} + int rand $floorwidth;
          } else {
            jot("H") if $debug > 6;
            # origin must be on the side
            jot(($xdir>0) ? "e" : "w") if $debug > 7;
            $$origin{x} = ($xdir > 0)
              ? $$room{stopx} + 1
              : $$room{startx} - 1;
            $floorheight = $$room{stopy} - $$room{starty} + 1;
            $$origin{y} = $$room{starty}
              + int rand $floorheight;
          }
          # Is that origin OK?  Note that we don't want to
          # allow origin at map edge.
          $originok = 1;
          # Do not allow origin at map edge:
          if (($$origin{x} < 2) or ($$origin{y} < 2) or
              ($$origin{x} + 2 >= $maxcols) or
              ($$origin{y} + 2 >= $maxrows)) {
            $originok = 0;
          }
          my $corridorlength = 0;
          if ($originok) {
            jot("O");
            if ((($pos[$$origin{y}][$$origin{x}]{char}
                  eq $horizwallchar)
                 and (($pos[$$origin{y}][$$origin{x}-1]{char}
                       eq $doorchar) or
                      ($pos[$$origin{y}][$$origin{x}-1]{char}
                       eq $sdoorchar) or
                      ($pos[$$origin{y}][$$origin{x}+1]{char}
                       eq $doorchar) or
                      ($pos[$$origin{y}][$$origin{x}+1]{char}
                       eq $sdoorchar))) or
                (($pos[$$origin{y}][$$origin{x}]{char}
                  eq $vertwallchar)
                 and (($pos[$$origin{y}-1][$$origin{x}]{char}
                       eq $doorchar) or
                      ($pos[$$origin{y}-1][$$origin{x}]{char}
                       eq $sdoorchar) or
                      ($pos[$$origin{y}+1][$$origin{x}]{char}
                       eq $doorchar) or
                      ($pos[$$origin{y}+1][$$origin{x}]{char}
                       eq $sdoorchar)))) {
              # Already Connected Here.
              jot("A") if $debug > 6;
            } else {
              $pos[$$origin{y}][$$origin{x}]{char} =
                $secret ? $sdoorchar : $doorchar;
              $pos[$$origin{y}][$$origin{x}]{colr} =
                $secret ? $sdoorcolor : $doorcolor;
              $pos[$$origin{y}][$$origin{x}]{terr} = 'door';
              if ($debug > 6) {
                my $color = $randcolor[rand @randcolor];
                $pos[$$origin{y}][$$origin{x}]{colr} = $color;
                print color $color;
                jot($doorchar);
                print color 'reset';
              }}
            my $y = $$origin{y};
            my $x = $$origin{x};
            my ($realy, $realx) = ($y, $x);
            jot($_) for split //, "y$y,x$x";
            my $connected = undef;
            my ($oldydir, $oldxdir) = ($ydir, $xdir);
            while ((not $connected) and
                   ($corridorlength <= $maxcorrlength)) {
              jot(",") if $debug > 20;
              my $loopcount = 0;
              $corrconn{$y}{$x}{$$room{room}} = 1;
              if ((rand(100) <= $corridortwist)
                  and $corridorlength) {
                ($oldxdir, $oldydir) = ($xdir, $ydir);
                $xdir = int rand(3) - 1;
                $ydir = int rand(3) - 1;
                jot("T") if $debug > 7;
              }
              while ((($x + $xdir < 0) or
                      ($x + $xdir >= $maxcols - 1) or
                      ($y + $ydir < 0) or
                      ($y + $ydir >= $maxrows - 1) or
                      (($xdir == 0) and ($ydir == 0)) or
                      (($oldxdir + $xdir == 0) and
                       ($oldydir + $ydir == 0))
                      #or ($pos[$y + $ydir][$x + $xdir]{crnr})
                     ) and ($loopcount++ < 1000)) {
                $xdir = int rand(3) - 1;
                $ydir = int rand(3) - 1;
              }
              warn "!" if ($loopcount >= 500 and $debug > 4);
              $xdir *= -1 if (($x + $xdir < 0) or
                              ($x + $xdir >= $maxcols - 1));
              $ydir *= -1 if (($y + $ydir < 0) or
                              ($y + $ydir >= $maxrows - 1));
              if (rand(100) < $jaggedcorr) {
                if (rand(100) < 50) {
                  $ydir *= (0.5 + (0.5 * rand(1)));
                } else {
                  $xdir *= (0.5 + (0.5 * rand(1)));
                }}
              if ($xdir and $ydir) {
                # When doing diagonals, attempt to fill in
                # an adjascent tile, to reduce the need for
                # squeezing through tight spaces:
                if (rand(100)<=60) {
                  # Try for an adjacent tile horizontally:
                  if ($pos[$y+int $ydir][$x]{char} eq $blankchar) {
                    $pos[$y + int $ydir][$x]{terr} = 'hall';
                    $pos[$y + int $ydir][$x]{char} = $corridorchar;
                    $pos[$y + int $ydir][$x]{colr} =
                      ($debug > 9) ? 'red' : $corridorcolor;
                  }
                } else {
                  # Try for an adjacent tile vertically:
                  if ($pos[$y][$x+int $xdir]{char} eq $blankchar) {
                    $pos[$y][$x + int $xdir]{terr} = 'hall';
                    $pos[$y][$x + int $xdir]{char} = $corridorchar;
                    $pos[$y][$x + int $xdir]{colr} =
                      ($debug > 9) ? 'green' : $corridorcolor;
                  }}}
              $realy += $ydir; $y = int $realy;
              $realx += $xdir; $x = int $realx;
              $corridorlength++;
              jot(".") if $debug > 8;
              if (($y >= $maxrows) or ($x >= $maxcols)
                  or ($x < 0) or ($y < 0)) {
                @pos = @save;
                $connected = 1;
                push @conn, 'edge'
                  if not ++$attempt % $connectretry;
                jot("e") if $debug > 7;
              }
              if (($pos[$y][$x]{terr} eq 'wall') or
                  ($pos[$y][$x]{terr} eq 'door')) {
                if ((($pos[$$origin{y}][$$origin{x}]{char}
                      eq $horizwallchar)
                     and (($pos[$$origin{y}][$$origin{x}-1]{char}
                           eq $doorchar) or
                          ($pos[$$origin{y}][$$origin{x}-1]{char}
                           eq $sdoorchar) or
                          ($pos[$$origin{y}][$$origin{x}+1]{char}
                           eq $doorchar) or
                          ($pos[$$origin{y}][$$origin{x}+1]{char}
                           eq $sdoorchar))) or
                    (($pos[$$origin{y}][$$origin{x}]{char}
                      eq $vertwallchar)
                     and (($pos[$$origin{y}-1][$$origin{x}]{char}
                           eq $doorchar) or
                          ($pos[$$origin{y}-1][$$origin{x}]{char}
                           eq $sdoorchar) or
                          ($pos[$$origin{y}+1][$$origin{x}]{char}
                           eq $doorchar) or
                          ($pos[$$origin{y}+1][$$origin{x}]{char}
                           eq $sdoorchar)))) {
                  # Already Connected Here.
                  jot("a") if $debug > 7;
                } else {
                  jot($doorchar) if $debug > 7;
                  $pos[$y][$x]{terr} = 'door';
                  $pos[$y][$x]{char} =
                    $secret ? $sdoorchar : $doorchar;
                  $pos[$y][$x]{colr} =
                    $secret ? $sdoorcolor : $doorcolor;
                }
                my $toroom = $pos[$y][$x]{room};
                if (not $conn{$$room{room}}{$toroom}) {
                  # We've connected to a new room.
                  $conn{$$room{room}}{$toroom}++;
                  $conn{$toroom}{$$room{room}}++;
                  push @conn, $toroom;
                  $connected = 1;
                  jot("*") if $debug > 6;
                } else {
                  # We've connected to an already-connected room.
                  $connected = 1;
                  push @conn, 'dupe'
                    if not ++$attempt % $connectretry;
                  jot("d") if $debug > 7;
                }
              } elsif ($pos[$y][$x]{terr} eq 'hall') {
                my @targ = grep {
                  not $conn{$_}{$$room{room}}
                    and not ($_ == $$room{room})
                  } keys %{$corrconn{$y}{$x}};
                if (@targ) {
                  jot($_), split //, "c:" . (join ",", @targ);
                  if (rand(100) >= $corridorcross) {
                    $connected = scalar @targ;
                    $attempt = 0;
                    jot("s"); # stop here
                  } else {
                    jot("c"); # continue
                  }
                  push @conn, $_ for @targ;
                  $conn{$_}{$$room{room}}++ for @targ;
                  $conn{$$room{room}}{$_}++ for @targ;
                }
                #jot("f") if $debug > 6;
                #push @conn, 'fail'
                #  if not ++$attempt % $connectretry;
              } elsif ($pos[$y][$x]{terr} eq 'floor') {
                $connected = 1;
                jot("?") if $debug > 6;
                push @conn, '????'
                  if not ++$attempt % $connectretry;
              } elsif ($pos[$y][$x]{terr} =~ /rock|default/) {
                jot("#") if $debug > 8;
                $pos[$y][$x]{terr} = 'hall';
                $pos[$y][$x]{char} = $corridorchar;
                $pos[$y][$x]{colr} = $corridorcolor;
              } elsif ($connectible{$pos[$y][$x]{terr}}) {
                $connected = 1;
                jot("?") if $debug > 6;
                push @conn, '????'
                  if not ++$attempt % $connectretry;
              } elsif ($pos[$y][$x]{terr} eq '') {
                warn "Uninitialized terrain at ($y,$x)\n";
                $connected = 1; push @conn, 'Error';
              } else {
                warn "Unhandled terrain type at ($y,$x): '"
                     . $pos[$y][$x]{terr} . "'";
                $connected = 1; push @conn, 'Error';
              }
            }}
        }}
    }
    $allcorridors -= 0.5;
  }
  ##warn "TODO: Hybrid Corridors Not Yet Fully Implemented.\n";
  ##$corridorstyle = 1 + int rand 3;
  ##warn "Using $corrname{$corridorstyle} corridors instead.\n";
  ##place_corridors();
}

sub place_directed_corridors {
  my @rm;
  my $connperroom = 2 + irr(3);
  for (1 .. $connperroom) {
    push @rm, $_ for map {
      $$_[0]
    } sort {
      $$a[1] <=> $$b[1]
    } map {
      [$_ => rand(7)]
    } @room;
  }
  while (@rm) {
    my $roomone = shift @rm;
    if (@rm) {
      my $roomtwo = shift @rm;
      if ($$roomone{room} == $$roomtwo{room}) {
        # This can happen occasionally if there are an odd
        # number of rooms, because the repeated shuffle
        # ordering can put the same room at the end of
        # one shuffle and beginning of the next shuffle.
        # Here's a feeble attempt to correct it:
        push @rm, $roomtwo;
        $roomtwo = shift @rm;
        # That should work unless the *same* room is
        # back-to-back on more than one occasion, or
        # back-to-back and also at the end of the list.
        # But there's only so much we can do, eh?
      }
      draw_corridor_between_rooms($roomone, $roomtwo);
    }}
}

sub point_within_room {
  my ($room) = @_;
  my $realx = $$room{startx}
    + rand($$room{stopx} - $$room{startx});
  my $realy = $$room{starty}
    + rand($$room{stopy} - $$room{starty});
  my $x = int $realx;
  my $y = int $realy;
  return ($y, $x, $realy, $realx);
}

sub draw_corridor_between_rooms {
  my ($rone, $rtwo) = @_;
  my ($yone, $xone) = point_within_room($rone);
  my ($ytwo, $xtwo) = point_within_room($rtwo);
  my $vdrop = abs($yone - $ytwo) || 0.1;
  my $hdrop = abs($xone - $xtwo) || 0.1;
  my ($ydir, $xdir, $targetlength);
  if ($vdrop > $hdrop) {
    # Mostly vertical with a bit of horizontal jag.
    $ydir = ($ytwo > $yone) ? 1 : -1;
    $xdir = $hdrop / $vdrop;
    $xdir *= -1 if ($xone > $xtwo);
    $targetlength = $vdrop * 2;
  } else {
    # Mostly horizontal with a bit of vertical jag.
    $xdir = ($xtwo > $xone) ? 1 : -1;
    $ydir = $vdrop / $hdrop;
    $ydir *= -1 if ($yone > $ytwo);
    $targetlength = $hdrop * 2;
  }
  #use Data::Dumper; warn Dumper(+{
  #                                pone => [$yone, $xone],
  #                                ptwo => [$ytwo, $xtwo],
  #                                drop => [$vdrop, $hdrop],
  #                                dirs => [$ydir, $xdir],
  #                                tlen => $targetlength,
  #                               });
  my ($realy, $realx, $y, $x) = ($yone, $xone);
  my $corridorlength = 0;
  my $secret = (rand(100) <= $secretprob) ? 1 : 0;
  while ($corridorlength < $targetlength) {
    if ($corridorlength % 2) {
      $realx += $xdir; $x = int $realx;
    } else {
      $realy += $ydir; $y = int $realy;
    }
    $corridorlength++;
    jot($_) for split //, "($y,$x)";
    if ($pos[$y][$x]{terr} eq 'wall') {
      $pos[$y][$x]{terr} = 'door';
      $pos[$y][$x]{char} = $secret ? $sdoorchar : $doorchar;
      $pos[$y][$x]{colr} = $secret ? $sdoorcolor : $doorcolor;
      jot($doorchar);
    } elsif ($pos[$y][$x]{terr} eq 'door') {
      jot($doorchar);
    } elsif ($connectible{$pos[$y][$x]{terr}}) {
      jot($floorchar);
    } elsif ($pos[$y][$x]{terr} =~ 'hall') {
      jot($corridorchar);
    } elsif ($pos[$y][$x]{terr} =~ 'rock|default') {
      $pos[$y][$x]{terr} = 'hall';
      $pos[$y][$x]{char} = $corridorchar;
      $pos[$y][$x]{colr} = $corridorcolor;
    } else {
      warn "Unhandled terrain type: '$pos[$y][$x]{terr}'";
    }
  }
}

sub place_haphazard_corridors {
  for my $room (map { $$_[0]
                    } sort { $$a[1] <=> $$b[1]
                           } map {  [$_, rand(953)]
                                  } @room) {
    my (@conn, %conn, $attempt);
    my $cwanted = 1 + int rand $corridorfreq;
    $cwanted = int($cwanted * 1.75) if $layoutstyle == 2;
    if ($debug > 10) {
      printlevel();
    }
    jot($_) for split //, " R$$room{room}CW$cwanted ";
    while (($cwanted > scalar @conn) and ($attempt < 25)) {
      jot("-");
      my ($xdir, $ydir, $origin) = (0, 0, +{});
      my $secret = (rand(100) <= $secretprob) ? 1 : 0;
      my @save = @pos;
      my $originok = 0;
      my ($origindir, $origintry);
      my ($floorwidth, $floorheight);
      while ((not $originok) and ($origintry++ < 80)) {
        while ((($xdir == 0) and ($ydir == 0))
               or ($xdir and $ydir) ) {
          $xdir = (int rand(3)) - 1;
          $ydir = (int rand(3)) - 1;
        }
        $origindir =
          (not $xdir)
            ? 'vert'
            : (not $ydir)
              ? 'horz'
              : (rand(100) >= 50) ? 'vert' : 'horz';
        if ($origindir eq 'vert') {
          jot("V") if $debug > 6;
          # origin must be top or bottom
          jot(($ydir>0) ? "n" : "s") if $debug > 7;
          $$origin{y} = ($ydir > 0)
            ? $$room{stopy} + 1
              : $$room{starty} - 1;
          $floorwidth = $$room{stopx} - $$room{startx} + 1;
          $$origin{x} = $$room{startx} + int rand $floorwidth;
        } else { jot("H") if $debug > 6;
                 # origin must be on the side
                 jot(($xdir>0) ? "e" : "w") if $debug > 7;
                 $$origin{x} = ($xdir > 0)
                   ? $$room{stopx} + 1
                     : $$room{startx} - 1;
                 $floorheight = 1+$$room{stopy} - $$room{starty};
                 $$origin{y} = $$room{starty}
                   + int rand $floorheight;
               }
        # Is that origin OK?  Note that we don't want to
        # allow origin at map edge.
        $originok = 1;
        # Do not allow origin at map edge:
        if (($$origin{x} < 2) or ($$origin{y} < 2) or
            ($$origin{x} + 2 >= $maxcols) or
            ($$origin{y} + 2 >= $maxrows)) {
          $originok = 0;
        }
        my $corridorlength = 0;
        if ($originok) {
          jot("O");
          if ((($pos[$$origin{y}][$$origin{x}]{char}
                eq $horizwallchar)
               and (($pos[$$origin{y}][$$origin{x}-1]{char}
                     eq $doorchar) or
                    ($pos[$$origin{y}][$$origin{x}-1]{char}
                     eq $sdoorchar) or
                    ($pos[$$origin{y}][$$origin{x}+1]{char}
                     eq $doorchar) or
                    ($pos[$$origin{y}][$$origin{x}+1]{char}
                     eq $sdoorchar))) or
              (($pos[$$origin{y}][$$origin{x}]{char}
                eq $vertwallchar)
               and (($pos[$$origin{y}-1][$$origin{x}]{char}
                     eq $doorchar) or
                    ($pos[$$origin{y}-1][$$origin{x}]{char}
                     eq $sdoorchar) or
                    ($pos[$$origin{y}+1][$$origin{x}]{char}
                     eq $doorchar) or
                    ($pos[$$origin{y}+1][$$origin{x}]{char}
                     eq $sdoorchar)))) {
            # Already Connected Here.
            jot("A") if $debug > 6;
          } else {
            $pos[$$origin{y}][$$origin{x}]{char} =
              $secret ? $sdoorchar : $doorchar;
            $pos[$$origin{y}][$$origin{x}]{colr} =
              $secret ? $sdoorcolor : $doorcolor;
            $pos[$$origin{y}][$$origin{x}]{terr} = 'door';
            if ($debug > 6) {
              my $color = $randcolor[rand @randcolor];
              $pos[$$origin{y}][$$origin{x}]{colr} = $color;
              print color $color;
              jot($doorchar);
              print color 'reset';
            }}
          my $x = $$origin{x};
          my $y = $$origin{y};
          jot($_) for split //, "y$y,x$x";
          my $connected = undef;
          my ($oldxdir, $oldydir);
          while (not $connected) {
            jot(",") if $debug > 20;
            my $loopcount = 0;
            if ((rand(100) <= $corridortwist)
                and $corridorlength) {
              ($oldxdir, $oldydir) = ($xdir, $ydir);
              $xdir = int rand(3) - 1;
              $ydir = int rand(3) - 1;
              jot("T") if $debug > 7;
            }
            while ((($x + $xdir < 0) or
                    ($x + $xdir >= $maxcols) or
                    ($y + $ydir < 0) or
                    ($y + $ydir >= $maxrows) or
                    (($xdir == 0) and ($ydir == 0)) or
                    (($oldxdir + $xdir == 0) and
                     ($oldydir + $ydir == 0)) or
                    ($pos[$y + $ydir][$x + $xdir]{crnr})
                   ) and ($loopcount++ < 1000)) {
              $xdir = int rand(3) - 1;
              $ydir = int rand(3) - 1;
            }
            warn "!" if ($loopcount >= 1000 and $debug > 2);
            $xdir *= -1 if (($x + $xdir < 0) or
                            ($x + $xdir >= $maxcols));
            $ydir *= -1 if (($y + $ydir < 0) or
                            ($y + $ydir >= $maxrows));
            if ($xdir and $ydir) {
              # When doing diagonals, attempt to fill in
              # an adjascent tile, to reduce the need for
              # squeezing through tight spaces:
              if (rand(100)<=60) {
                # Try for an adjacent tile horizontally:
                if ($pos[$y + $ydir][$x]{char} eq $blankchar) {
                  $pos[$y + $ydir][$x]{terr} = 'hall';
                  $pos[$y + $ydir][$x]{char} = $corridorchar;
                  $pos[$y + $ydir][$x]{colr} =
                    ($debug > 9) ? 'red' : $corridorcolor;
                }
              } else {
                # Try for an adjacent tile vertically:
                if ($pos[$y][$x + $xdir]{char} eq $blankchar) {
                  $pos[$y][$x + $xdir]{terr} = 'hall';
                  $pos[$y][$x + $xdir]{char} = $corridorchar;
                  $pos[$y][$x + $xdir]{colr} =
                    ($debug > 9) ? 'green' : $corridorcolor;
                }
              }
            }
            $x += $xdir;
            $y += $ydir;
            $corridorlength++ if ($xdir or $ydir);
            jot(".") if $debug > 8;
            if (($y > $maxrows) or ($x > $maxcols)
                or ($x < 0) or ($y < 0)) {
              @pos = @save;
              $connected = 1;
              push @conn, 'edge'
                if not ++$attempt % $connectretry;
              jot("e") if $debug > 7;
            }
            if (($pos[$y][$x]{terr} eq 'wall') or
                ($pos[$y][$x]{terr} eq 'door')) {
              if ((($pos[$$origin{y}][$$origin{x}]{char}
                    eq $horizwallchar)
                   and (($pos[$$origin{y}][$$origin{x}-1]{char}
                         eq $doorchar) or
                        ($pos[$$origin{y}][$$origin{x}-1]{char}
                         eq $sdoorchar) or
                        ($pos[$$origin{y}][$$origin{x}+1]{char}
                         eq $doorchar) or
                        ($pos[$$origin{y}][$$origin{x}+1]{char}
                         eq $sdoorchar))) or
                  (($pos[$$origin{y}][$$origin{x}]{char}
                    eq $vertwallchar)
                   and (($pos[$$origin{y}-1][$$origin{x}]{char}
                         eq $doorchar) or
                        ($pos[$$origin{y}-1][$$origin{x}]{char}
                         eq $sdoorchar) or
                        ($pos[$$origin{y}+1][$$origin{x}]{char}
                         eq $doorchar) or
                        ($pos[$$origin{y}+1][$$origin{x}]{char}
                         eq $sdoorchar)))) {
                # Already Connected Here.
                jot("a") if $debug > 7;
              } else {
                jot($doorchar) if $debug > 7;
                $pos[$y][$x]{terr} = 'door';
                $pos[$y][$x]{char} =
                  $secret ? $sdoorchar : $doorchar;
                $pos[$y][$x]{colr} =
                  $secret ? $sdoorcolor : $doorcolor;
              }
              my $toroom = $pos[$y][$x]{room};
              if (not $conn{$$room{room}}{$toroom}) {
                # We've connected to a new room.
                $conn{$$room{room}}{$toroom}++;
                $conn{$toroom}{$$room{room}}++;
                push @conn, $toroom;
                $connected = 1;
                jot("*") if $debug > 6;
              } else {
                # We've connected to an already-connected room.
                $connected = 1;
                push @conn, 'dupe'
                  if not ++$attempt % $connectretry;
                jot("d") if $debug > 7;
              }
            } elsif ($pos[$y][$x]{terr} eq 'hall') {
              $connected = 1;
              jot("f") if $debug > 6;
              push @conn, 'fail'
                if not ++$attempt % $connectretry;
            } elsif ($pos[$y][$x]{terr} eq 'floor') {
              $connected = 1;
              jot("?") if $debug > 6;
              push @conn, '????'
                if not ++$attempt % $connectretry;
            } elsif ($pos[$y][$x]{terr} =~ /rock|default/) {
              jot("#") if $debug > 8;
              $pos[$y][$x]{terr} = 'hall';
              $pos[$y][$x]{char} = $corridorchar;
              $pos[$y][$x]{colr} = $corridorcolor;
            } else {
              warn "Unhandled terrain type: '$pos[$y][$x]{terr}'";
              $connected = 1; push @conn, 'Error';
            }
          }}
      }}
  }}

sub interp {
  my ($one, $two, $v) = @_;
  my $avg = ($one + $two) / 2;
  my $var = rand($v * $fractalvaries)
              - ($v * $fractalvaries / 2);
  my $jit = $v ? (rand($fractaljitter)-($fractaljitter/2)) : 0;
  return $avg + $var + $jit;
}

sub calculate_plasma {
  my ($miny, $minx, $maxy, $maxx, $iter) = @_;
  die "BUG" if $iter > $maxcols + $maxrows;
  if (not $iter) {
    $miny = 0;
    $maxy = $maxrows - 1;
    $minx = 0;
    $maxx = $maxcols - 1;
    $pos[$miny][$minx]{frac} = 30 + rand(50);
    $pos[$miny][$maxx]{frac} = 30 + rand(50);
    $pos[$maxy][$minx]{frac} = 30 + rand(50);
    $pos[$maxy][$maxx]{frac} = 30 + rand(50);
  }
  if (($miny + 1 >= $maxy) and ($minx + 1 >= $maxx)) {
    # We're down to just one point, no need to recurse further.
    return;
  }
  my $midx = $minx + int(($maxx - $minx)/2);
  my $midy = $miny + int(($maxy - $miny)/2);
  $pos[$miny][$midx]{frac} = interp($pos[$miny][$minx]{frac},
                                    $pos[$miny][$maxx]{frac},
                                    ($maxx - $minx));
  $pos[$maxy][$midx]{frac} = interp($pos[$maxy][$minx]{frac},
                                    $pos[$maxy][$maxx]{frac},
                                    ($maxx - $minx));
  $pos[$midy][$minx]{frac} = interp($pos[$miny][$minx]{frac},
                                    $pos[$maxy][$minx]{frac},
                                    ($maxy - $miny));
  $pos[$midy][$maxx]{frac} = interp($pos[$miny][$maxx]{frac},
                                    $pos[$maxy][$maxx]{frac},
                                    ($maxy - $miny));
  my $vmid = interp($pos[$midy][$minx]{frac},
                    $pos[$midy][$maxx]{frac},
                    ($maxx - $minx));
  my $hmid = interp($pos[$miny][$midx]{frac},
                    $pos[$maxy][$midx]{frac}, 0);
  $pos[$midy][$maxx]{frac} = interp($vmid, $hmid, 0);
  printf("($miny, $minx): %0.2f, "
      . "($maxy, $maxx): %0.2f, "
      . "($midy, $midx): %0.2f [$iter]\n",
         $pos[$miny][$minx]{frac}, $pos[$maxy][$maxx]{frac},
         $pos[$midy][$midx]{frac})
    if $debug > 4;
  calculate_plasma($miny, $minx, $midy, $midx, $iter + 1);
  calculate_plasma($miny, $midx, $midy, $maxx, $iter + 1);
  calculate_plasma($midy, $minx, $maxy, $midx, $iter + 1);
  calculate_plasma($midy, $midx, $maxy, $maxx, $iter + 1);
}

sub layout_plasma_fractal {
  my ($liquidterr, $liquidchar, $liquidcolor);
  if (rand(100) < 50) {
    ($liquidterr, $liquidchar, $liquidcolor)
      = ('pool', $poolchar, $poolcolor);
  } else {
    ($liquidterr, $liquidchar, $liquidcolor)
      = ('lava', $lavachar, $lavacolor);
  }
  calculate_plasma();
  for my $y (0 .. ($maxrows - 1)) {
    for my $x (0 .. $maxcols - 1) {
      my $fracval = $pos[$y][$x]{frac};
      if ($fracval <= $liquidthresh) {
        $pos[$y][$x]{terr} = $liquidterr;
        $pos[$y][$x]{char} = $liquidchar;
        $pos[$y][$x]{colr} = $liquidcolor;
      } elsif ($fracval <= $floorthresh) {
        $pos[$y][$x]{terr} = 'floor';
        $pos[$y][$x]{char} = $floorchar;
        $pos[$y][$x]{colr} = $floorcolor;
      } elsif ($fracval <= $corridorthresh) {
        $pos[$y][$x]{terr} = 'hall';
        $pos[$y][$x]{char} = $corridorchar;
        $pos[$y][$x]{colr} = $corridorcolor;
      } else {
        $pos[$y][$x]{terr} = 'rock';
        $pos[$y][$x]{char} = $blankchar;
        $pos[$y][$x]{colr} = 'reset';
      }
    }}
}

sub layout_non_rectangular_rooms {
  $maxroomwidth  += irr(($maxcols - $maxroomwidth)  * 2/3);
  $maxroomheight += irr(($maxrows - $maxroomheight) * 2/3);
  my $avgwidth    = ($minroomwidth + $maxroomwidth) / 2;
  my $avgheight   = ($minroomheight + $maxroomheight) / 2;
  my $numofrooms  = ($maxcols / $avgwidth)
                  * ($maxrows / $avgheight);
  $numofrooms = int(
                    ($numofrooms / 3)
                    + rand($numofrooms / 3)
                   );
  my $tries = 0;
  while (($numofrooms > scalar @room) and ($tries++ < 250)) {
    my $targetwidth  = $maxroomwidth
                     - irr($maxroomwidth - $minroomwidth);
    my $targetheight = $maxroomheight
                     - irr($maxroomheight - $minroomheight);
    jot($_) for split //, ('W' . $targetwidth
                           ."H" . $targetheight . ":");
    my $mainrect = randomrect($targetheight, $targetwidth);
    if (rectavailable($mainrect)) {
      $$mainrect{room} = ++$roomnum;
      jot("R"); jot($_) for split //, $roomnum;
      jot($_) for split //,
        qq[x$$mainrect{startx}y$$mainrect{starty}];
      my $vr = +{ map { $_ => $$mainrect{$_} } keys %$mainrect };
      my $hr = +{ map { $_ => $$mainrect{$_} } keys %$mainrect };
      my %specialcolor=(1 => 'cyan', 2 => 'red', 3 => 'magenta',
                        4 => 'green', 5 => 'blue', 6 => 'yellow');
      my $roomstyle = 1 + int rand 7;
      print color $specialcolor{$roomstyle} if $debug > 3;
      jot("S"); jot($roomstyle);
      print color 'reset';
      if ($roomstyle == 1) { # L-shaped room
        # vr and hr overlap, each forming one arm/wing.
        my $hpinch = ($$vr{stopx} - $$vr{startx})
          - int rand (($$vr{stopx} - $$vr{startx})/2);
        jot($_) for split //, $hpinch;
        if (rand(100)<= 50) {
          jot("r");
          $$vr{startx} += $hpinch;
        } else {
          jot("l");
          $$vr{stopx}  -= $hpinch;
        }
        my $vpinch = $$hr{stopy} - $$hr{starty}
          - int rand (($$hr{stopy} - $$hr{starty})/2);
        jot($_) for split //, $vpinch;
        if (rand(100)<= 50) {
          jot("b");
          $$hr{starty} += $vpinch;
        } else {
          jot("t");
          $$hr{stopy} -=  $vpinch;
        }
      } elsif ($roomstyle == 2) { # T-shaped room
        # vr and hr overlap, forming the body and bar of the T.
        if (rand(100) <= 50) {
          # Vertical T
          jot("v");
          my $pinch = 1 + int rand(($$vr{stopx}-$$vr{startx}-1)/2);
          jot($_) for split //, $pinch;
          $$vr{startx} += $pinch;
          $$vr{stopx}  -= $pinch;
          my $lift = 1 + irr(abs($$hr{stopy} - $$hr{starty} - 1));
          if (rand(100) <= 50) { # Rightside-up T
            jot("t");
            $$hr{starty} += $lift;
          } else { # Upside-down T
            jot("b");
            $$hr{stopy}  -= $lift;
          }
          jot($_) for split //, $lift;
        } else {
          # Horizontal |- or -|
          jot("h");
          my $pinch = 1 + int rand(($$hr{stopy}-$$hr{starty}-1)/2);
          jot($_) for split //, $pinch;
          $$hr{starty} += $pinch;
          $$hr{stopy}  -= $pinch;
          my $lift = 1 + irr(abs($$vr{stopx} - $$vr{startx} - 1));
          if (rand(100) <= 50) {
            jot("r");
            $$vr{startx} += $lift;
          } else {
            jot("l");
            $$vr{stopx}  -= $lift;
          }
          jot($_) for split //, $lift;
        }
      } elsif ($roomstyle == 3) { # Cross-shaped room
        # vr and hr overlap, crossing in the middle
        jot("+");
        my $vpinch = 1+int rand(($$vr{stopx}-$$vr{startx}-1)/2);
        $$vr{startx} += $vpinch;
        $$vr{stopx}  -= $vpinch;
        my $hpinch = 1+int rand(($$hr{stopy}-$$hr{starty}-1)/2);
        $$hr{starty} += $hpinch;
        $$hr{stopy}  -= $hpinch;
        jot($_) for split //, $vpinch;
        jot(",");
        jot($_) for split //, $hpinch;
      } elsif ($roomstyle == 4) {
        # What do you call that other Tetris piece?
        # Anyway, vr and hr overlap again here.
        my $vpinch = 1+int rand(abs($$vr{stopx}-$$vr{startx}-1)/2);
        my $hpinch = 1+int rand(abs($$hr{stopy}-$$hr{starty}-1)/2);
        jot($_) for split //, $vpinch;
        jot(",");
        jot($_) for split //, $hpinch;
        if (rand(100) <= 50) {
          # pinch the lower left and upper right
          jot("a");
          $$vr{stopx}  -= $hpinch;
          $$vr{stopy}  -= $vpinch;
          $$hr{startx} += $hpinch;
          $$hr{starty} += $vpinch;
          while ($$vr{stopy} <= $$hr{starty}) {
            $$vr{stopy}++;
            $$hr{starty}--;
          }
        } else {
          # pinch the upper left and lower right
          jot("b");
          $$vr{startx} += $hpinch;
          $$vr{stopy}  -= $vpinch;
          $$hr{stopx}  -= $hpinch;
          $$hr{starty} += $vpinch;
          while ($$vr{stopy} <= $$hr{starty}) {
            $$vr{stopy}++;
            $$hr{starty}--;
          }
        }
      } elsif ($roomstyle == 5) { # U-shaped room
        # hr stays full size; vr shrinks and is the cutout.
        my $hpinch = 1+int(($$vr{stopx} - $$vr{startx})/3);
        my $vpinch = 1+int(($$vr{stopy} - $$vr{starty})/3);
        if (rand(100)<70) { # Vertical U:
          $$vr{startx} += $hpinch;
          $$vr{stopx}  -= $hpinch;
          while ($$vr{stopx} <= $$vr{startx}) {
            if (rand(100)<50) {
              $$vr{startx}--;
            } else {
              $$vr{stopx}++;
            }}
          if (rand(100)<50) { # Rightside-up U:
            $$vr{stopy}  -= $vpinch;
          } else { # Upside-down U:
            $$vr{starty} += $vpinch;
          }
        } else { # Horizontal U:
          $$vr{starty} += $vpinch;
          $$vr{stopy}  -= $vpinch;
          while ($$vr{stopy} <= $$vr{starty}) {
            if (rand(100)<50) {
              $$vr{starty}--;
            } else {
              $$vr{stopy}++;
            }}
          if (rand(100)<50) { # Gap on Left:
            $$vr{stopx}  -= $hpinch;
          } else { # Gap on Right:
            $$vr{startx} += $hpinch;
          }}
      } elsif ($roomstyle == 6) { # Room with two pillars cut out.
        my $pillarwidth  = irr($$vr{stopx} - $$vr{stopx}) + 1;
        my $pillarheight = irr($$vr{stopy} - $$vr{starty});
        my $hslop = ($$vr{stopx} - $$vr{startx})
          - $pillarwidth - 1;
        my $vslop = ($$vr{stopy} - $$vr{starty})
          - $pillarheight - 1;
        while (($hslop < 2) and ($pillarwidth > 1)) {
          $pillarwidth--; $hslop++; }
        while (($vslop < 2) and ($pillarheight > 0)) {
          $pillarheight--; $vslop++;
        }
        $$vr{startx} = $$mainrect{startx} + 1 + int rand $hslop;
        $$vr{starty} = $$mainrect{starty} + 1 + int rand $vslop;
        $$hr{startx} = $$mainrect{startx} + 1 + int rand $hslop;
        $$hr{starty} = $$mainrect{starty} + 1 + int rand $vslop;
        $$vr{stopx}  = $$vr{startx} + $pillarwidth;
        $$vr{stopy}  = $$vr{starty} + $pillarheight;
        $$hr{stopx}  = $$hr{startx} + $pillarwidth;
        $$hr{stopy}  = $$hr{starty} + $pillarheight;
      } else { # roomstyle 7 is a plain rectangle
        # vr and hr are irrelevant here.
        $mainrect = makeroom($mainrect);
      }
      if ($roomstyle <= 4) {
        # This is the case where vr and hr overlap.
        # Leave room around the edge (for corridors):
        leaveroomforcorridors($hr);
        leaveroomforcorridors($vr);
        # Fill in the walls:
        makewalls($hr);
        local $wallcolor = $specialcolor{$roomstyle}
          if $debug > 3;
        makewalls($vr);
        # Now fill in the floor, right overtop of any walls
        # that would otherwise run through it:
        makefloor($hr);
        local $floorcolor = $specialcolor{$roomstyle}
          if $debug > 3;
        makefloor($vr);
      } elsif ($roomstyle <= 6) {
        # Start with mainrect then subtract vr and maybe hr.
        leaveroomforcorridors($mainrect);
        makewalls($mainrect);
        local $floorcolor = $specialcolor{$roomstyle}
          if $debug > 3;
        makefloor($mainrect);
        unmakefloor($vr);
        unmakefloor($hr) if $roomstyle == 6;
        local $wallcolor = $specialcolor{$roomstyle}
          if $debug > 3;
        makewalls($vr);
        makewalls($hr) if $roomstyle == 6;
      } else {
        # already called makeroom, vr and hr don't matter.
      }
      push @room, $mainrect;
    } else {
      jot("u");
    }
  }
  print "\n\n";
  if ($debug > 4) {
    printlevel();
    print "\n\n";
  }
}

sub layout_overlapping_rooms {
  my $avgwidth   = ($minroomwidth + $maxroomwidth) / 2;
  my $avgheight  = ($minroomheight + $maxroomheight) / 2;
  my $numofrooms = ($maxcols / $avgwidth)
                 * ($maxrows / $avgheight);
  $numofrooms = int(
                    ($numofrooms / 3)
                    + rand($numofrooms / 3)
                   );
  for (1 .. $numofrooms) {
    my $targetwidth  = $minroomwidth
                     + int rand ($maxroomwidth - $minroomwidth);
    my $targetheight = $minroomheight
                     + int rand ($maxroomheight - $minroomheight);
    my $rect = randomrect($targetheight, $targetwidth);
    push @room, makeroom($rect);
  }
  # makeroom() assumed no overlap, so we need to fix
  # up a few things.  We can assume the floor is in place,
  # but walls may have been lost, so we must restore them:
  for my $room (@room) {
    # Restore Vertical Boundaries:
    for my $y   (($$room{starty} - 1) .. ($$room{stopy} + 1)) {
      for my $x (($$room{startx} - 1), ($$room{stopx} + 1)) {
        if (($x >= 0) and ($y >= 0) and
            ($x < $maxcols) and ($y < $maxrows)) {
          $pos[$y][$x]{terr} = 'wall';
          $pos[$y][$x]{char} = $vertwallchar;
          $pos[$y][$x]{colr} = $wallcolor;
          $pos[$y][$x]{room} ||= $roomnum;
        }}}
    # Restore Horizontal Boundaries:
    for my $y   (($$room{starty} - 1), ($$room{stopy} + 1)) {
      for my $x (($$room{startx} - 1) .. ($$room{stopx} + 1)) {
        if (($x >= 0) and ($y >= 0) and
            ($x < $maxcols) and ($y < $maxrows)) {
          $pos[$y][$x]{terr} = 'wall';
          $pos[$y][$x]{char} = $horizwallchar;
          $pos[$y][$x]{colr} = $wallcolor;
          $pos[$y][$x]{room} ||= $roomnum;
        }}}
    # Where there are more than two parallel walls, we
    # want to put floor in the middle...
    for my $y (1 .. ($maxrows - 2)) {
      for my $x (1 .. ($maxcols - 2)) {
        # Horizontal parallel walls (more likely):
        if (($pos[$y - 1][$x]{terr} eq 'wall') and
            ($pos[$y][$x]{terr} eq 'wall') and
            ($pos[$y + 1][$x]{terr} eq 'wall') and
            ($pos[$y - 1][$x]{char} eq $horizwallchar) and
            ($pos[$y][$x]{char} eq $horizwallchar)) {
          $pos[$y][$x]{terr} = 'floor';
          $pos[$y][$x]{colr} = $floorcolor;
          $pos[$y][$x]{char} = $floorchar;
        }
        # Vertical parallel walls (also possible):
        if (($pos[$y][$x - 1]{terr} eq 'wall') and
            ($pos[$y][$x]{terr} eq 'wall') and
            ($pos[$y][$x + 1]{terr} eq 'wall') and
            ($pos[$y][$x - 1]{char} eq $vertwallchar) and
            ($pos[$y][$x]{char} eq $vertwallchar)) {
          $pos[$y][$x]{terr} = 'floor';
          $pos[$y][$x]{colr} = $floorcolor;
          $pos[$y][$x]{char} = $floorchar;
        }
      }}

    # Other fixup would go here, if needed, but I think that
    # might just about cover it.
  }
}

sub layout_dense_rooms {
  my $targetwidth  = $maxroomwidth;
  my $targetheight = $maxroomheight;
  my $availtiles   = $maxrows * $maxcols;
  my ($iteration, $totaliteration);

  while (($targetwidth  >= $minroomwidth) and
         ($targetheight >= $minroomheight) and
         ($availtiles   >= ($minroomwidth *
                            $minroomheight * 10))) {
    my $height = ($targetheight > 3)
      ? $targetheight - irr($targetheight) : $targetheight;
    my $width  = ($targetwidth > 5)
      ? $targetwidth  - irr($targetwidth)  : $targetwidth;
    my $rect = randomrect($height, $width);
    if (rectavailable($rect)) {
      jot("+", 0);
      push @room, makeroom($rect);
      #use Data::Dumper; print Dumper(+{ room => \@room });
      printlevel() if $debug > 4;
    }
    my $fitratio = int($availtiles * 5
                       / ($targetwidth * $targetheight));
    if ($iteration++ > $fitratio) {
      # We've tried enough times at this size.  Decrease size.
      my $aspectratio = $targetwidth / $targetheight;
      if (rand(100) <= (20 * $aspectratio)) {
        $targetwidth -= (1 + int rand ($targetwidth /
                                       $widthdivisor));
        jot($_, 2) for split //, "W$targetwidth";
      } else {
        $targetheight -= (1 + int rand ($targetheight /
                                        $heightdivisor));
        jot($_, 2) for split //, "H$targetheight";
      }
      jot(" ");
      $totaliteration += $iteration;
      $iteration = 0;
    } else {
      jot();
    }
  }
}

sub printlevel {
  print color 'reset';
  print "\n
Layout Style: $layoutstyle ($layoutname{$layoutstyle})
Corridor Style: $corridorstyle ($corrname{$corridorstyle})\n\n";
  for my $row (@pos) {
    for my $cell (@$row) {
      if (ref $$cell{mons}) {
        print color $$cell{mons}{colr} if $$cell{mons}{colr};
        print $$cell{mons}{char};
     #} elsif ($$cell{objs}) { # TODO
      } else {
        print color $$cell{colr} if $$cell{colr};
        if ($$cell{char}) {
          print $$cell{char};
        } elsif ($$cell{room}) {
          my $digit = $$cell{room} % 10;
          print $digit;
        } else {
          print $errorchar;
        }
      }
      print color 'reset';
    }
    print color 'reset';
    print "\n";
  }
}

sub jot {
  my ($char, $mindebuglevel) = @_;
  $char ||= '.';
  $mindebuglevel ||= 1;
  if ($mindebuglevel + 3 <= $debug) {
    print $char;
    if (not ($jotcount++ % 60)) {
      print "\n";
    }
  }
}

sub randomrect {
  my ($theight, $twidth) = @_;
  my $maxy   = $maxrows - $theight - 1;
  my $maxx   = $maxcols - $twidth - 1;
  my $starty = 1 + int rand $maxy;
  my $startx = 1 + int rand $maxx;
  return +{
           starty => $starty,
           startx => $startx,
           stopy  => $starty + $theight - 1,
           stopx  => $startx + $twidth - 1,
          };
}

sub rectavailable {
  my ($rect) = @_;
  for my $y ($$rect{starty} .. $$rect{stopy}) {
    for my $x ($$rect{startx} .. $$rect{stopx}) {
      if (defined $pos[$y][$x]{room}) {
        return;
      } elsif (not ($pos[$y][$x]{terr} =~ /default/)) {
        return;
      }
    }
  }
  return $rect;
}

sub makeroom {
  my ($room, %arg) = @_;
  $$room{room} = ++$roomnum;
  makefloor($room);
  leaveroomforcorridors($room);
  makewalls($room);
  return $room;
}

sub unmakefloor {
  my ($room) = @_;
  for my $y ($$room{starty} .. $$room{stopy}) {
    for my $x ($$room{startx} .. $$room{stopx}) {
      $pos[$y][$x]{room} = $roomnum;
      $pos[$y][$x]{terr} = 'rock';
      $pos[$y][$x]{colr} = 'reset';
      $pos[$y][$x]{char} = $blankchar;
    }}
  return $room;
}

sub makefloor {
  my ($room) = @_;
  for my $y ($$room{starty} .. $$room{stopy}) {
    for my $x ($$room{startx} .. $$room{stopx}) {
      $pos[$y][$x]{room} = $roomnum;
      $pos[$y][$x]{terr} = 'floor';
      $pos[$y][$x]{colr} = $floorcolor;
      $pos[$y][$x]{char} = $floorchar;
    }}
  return $room;
}

sub makewalls {
  my ($room) = @_;
  # Horizontal Boundaries:
  for my $y   (($$room{starty} - 1), ($$room{stopy} + 1)) {
    for my $x (($$room{startx} - 1) .. ($$room{stopx} + 1)) {
      if (($x >= 0) and ($y >= 0) and
          ($x < $maxcols) and ($y < $maxrows)) {
        $pos[$y][$x]{terr} = 'wall';
        $pos[$y][$x]{char} = $horizwallchar;
        $pos[$y][$x]{colr} = $wallcolor;
        $pos[$y][$x]{room} ||= $$room{room};
      }}}
  # Vertical Boundaries:
  for my $y   (($$room{starty} - 1) .. ($$room{stopy} + 1)) {
    for my $x (($$room{startx} - 1), ($$room{stopx} + 1)) {
      if (($x >= 0) and ($y >= 0) and
          ($x < $maxcols) and ($y < $maxrows)) {
        $pos[$y][$x]{terr} = 'wall';
        $pos[$y][$x]{char} = $vertwallchar;
        $pos[$y][$x]{colr} = $wallcolor;
        $pos[$y][$x]{room} ||= $$room{room};
      }
    }
  }
  # Corners:
  if (($$room{starty} >= 1) and ($$room{startx} >= 1)) {
    $pos[$$room{starty} - 1][$$room{startx} - 1]{char}
      = $nwcornerchar;
    $pos[$$room{starty} - 1][$$room{startx} - 1]{crnr} = 1;
  }
  if (($$room{starty} >= 1) and ($$room{stopx} + 1 < $maxcols)) {
    $pos[$$room{starty} - 1][$$room{stopx} + 1]{char}
      = $necornerchar;
    $pos[$$room{starty} - 1][$$room{stopx} + 1]{crnr} = 1;
  }
  if (($$room{stopy} + 1 < $maxrows) and
      ($$room{stopx} + 1 < $maxcols)) {
    $pos[$$room{stopy} + 1][$$room{stopx} + 1]{char}
      = $secornerchar;
    $pos[$$room{stopy} + 1][$$room{stopx} + 1]{crnr} = 1;
  }
  if (($$room{stopy} + 1 < $maxrows) and ($$room{startx} >= 1)) {
    $pos[$$room{stopy} + 1][$$room{startx} - 1]{char}
      = $swcornerchar;
    $pos[$$room{stopy} + 1][$$room{startx} - 1]{crnr} = 1;
  }
  return $room;
}

sub leaveroomforcorridors {
  my ($room) = @_;
  # Leave room for horizontal corridors:
  for my $y   (($$room{starty} - 2), ($$room{stopy} + 2)) {
    for my $x (($$room{startx} - 2) .. ($$room{stopx} + 2)) {
      if (($x >= 0) and ($y >= 0) and
          ($x < $maxcols) and ($y < $maxrows)) {
        $pos[$y][$x]{terr} = 'rock';
      }}}
  # Leave room for vertical corridors:
  for my $y   (($$room{starty} - 2) .. ($$room{stopy} + 2)) {
    for my $x (($$room{startx} - 2), ($$room{stopx} + 2)) {
      if (($x >= 0) and ($y >= 0) and
          ($x < $maxcols) and ($y < $maxrows)) {
        $pos[$y][$x]{terr} = 'rock';
      }}}
  return $room;
}

sub placefurniture {
  my ($room, $terrain, $char, $colr, $y, $x) = @_;
  ($y, $x) = placeonfloor($room) if not defined $x;
  if ($pos[$y][$x]{terr} eq 'floor') {
    $pos[$y][$x]{terr} = $terrain || 'ERROR';
    $pos[$y][$x]{char} = $char || $errorchar;
    $pos[$y][$x]{colr} = $colr || $errorcolor;
    push @{$pos[$y][$x]{furn}}, +{
                                  y    => $y,
                                  x    => $x,
                                  type => $terrain,
                                 };
    return [$y, $x];
  }
}

sub placemonster {
  my ($room, $type, $char, $colr) = @_;
  my $tried = 0;
  while ($tried++ < 15) {
    # Only place one monster per tile:
    my ($y, $x) = placeonfloor($room);
    if (($pos[$y][$x]{terr} eq 'floor') and
        (not ref $pos[$y][$x]{mons})){
      $pos[$y][$x]{mons} = +{
                             char => $char || $errorchar,
                             type => $type || 'MONSTER',
                             colr => $colr || 'reset',
                            };
      return [$y, $x];
    }}
}

sub placeonfloor {
  my ($room) = @_;
  my $miny = $$room{starty};
  my $minx = $$room{startx};
  my $maxy = $$room{stopy};
  my $maxx = $$room{stopx};
  my $tried = 0;
  while ($tried++ < 25) {
    my $y = $miny + (int rand($maxy + 1 - $miny));
    my $x = $minx + (int rand($maxx + 1 - $minx));
    print "[$y,$x]" if $debug > 30;
    if ($pos[$y][$x]{terr} eq 'floor') {
      return ($y, $x);
    }}
  return ($miny, $minx);
}

sub irr {
  my ($num) = @_;
  return int rand rand $num;
}
