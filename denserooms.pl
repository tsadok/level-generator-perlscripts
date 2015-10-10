#!/usr/bin/perl
# -*- cperl -*-

# This is a Perl program that generates a proposed new type
# of NetHack level, consisting of a denser packing of rooms
# and corridors than the traditional one.  This is strictly
# experimental, and of course this Perl code will not
# integrate into NetHack, so in order to be used it would
# need to be reimplemented in C and integrated into
# NetHack's existing level-generation code.

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
# (e.g., doors on the corners of rooms shouldn't happen),
# but I think it's reached the point where it's worth
# soliciting feedback...

# If the idea of new kinds of levels to mix in with the
# mazes in Gehennom interests you, please run this Perl
# script a few times and let me know what you think.
# Specific suggestions are welcome.

my %arg = @ARGV;

my $debug         = $arg{debug}         || 3;
my $maxrows       = $arg{maxrows}       || 24;
my $maxcols       = $arg{maxcols}       || 65 + int rand(4);
my $minroomwidth  = $arg{minroomwidth}  || 2  + int rand(3);
my $minroomheight = $arg{minroomheight} || 2  + int rand(2);
my $minrectwidth  = $minroomwidth  + 2 + int rand(3);
my $minrectheight = $minroomheight + 2;# + int rand(1);
print "Min rect: $minrectwidth x $minrectheight"
  . "; min room: $minroomwidth x $minroomheight\n" if $debug;
my $maxrectwidth  = $arg{maxrectwidth}  || 11 + int rand(5);
my $maxrectheight = $arg{maxrectheight} || 6  + int rand(3);
my $roomprob      = $arg{roomprob}      || 90;
my $secretprob    = $arg{secretprob}    || 30;
my $blankchar     = $arg{blankchar}     || ' ';
my $corridorchar  = $arg{corridorchar}  || '#';
my $floorchar     = $arg{floorchar}     || '.';
my $horizwallchar = $arg{horizwallchar} || '-';
my $vertwallchar  = $arg{vertwallchar}  || '|';
my $doorchar      = $arg{doorchar}      || '+';
my $sdoorchar     = $arg{sdoorchar}     || '+';
my $nwcornerchar  = $arg{nwcornerchar}  || '-';
my $necornerchar  = $arg{necornerchar}  || '-';
my $swcornerchar  = $arg{swcornerchar}  || '-';
my $secornerchar  = $arg{secornerchar}  || '-';
my $errorchar     = $arg{errorchar}     || 'E';
my $errorcolor    = $arg{errorcolor}    || 'bold yellow on_red';
my $wallcolor     = $arg{wallcolor}     || 'white on_black';
my $floorcolor    = $arg{floorcolor}    || 'reset';
my $doorcolor     = $arg{doorcolor}     || 'yellow on_black';
my $sdoorcolor    = $arg{sdoorcolor}    || $wallcolor;
my $corridorcolor = $arg{corridorcolor} || 'reset';
my $corridorfreq  = $arg{corridorfreq}  || 2 + int rand 2;
my $corridortwist = $arg{corridortwist} || 12;
my $connectretry  = $arg{connectretry}  || 3;
my $mergethreshold= $arg{mergethreshold}|| 2;
my $mergeprob     = $arg{mergeprob}     || 45;
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

$|=1;

while ($maxrectwidth < $minrectwidth + 2) {
  warn "Max rect width ("
    . $maxrectwidth . ") too small; adjusting.";
  ++$maxrectwidth;
}
while ($maxrectheight < $minrectheight + 1) {
  warn "Max rect height ("
    . $maxrectheight. ") too small; adjusting.";
  ++$maxrectheight;
}

die "Not enough columns to fit a max-size rect."
  if $maxcols < $maxrectwidth;
die "Not enough rows to fit a max-size rect."
  if $maxrows < $maxrectheight;

use Term::ANSIColor;

# First, lay out a basic grid of rectangles:
my @cellcol;
my @rect; {
  my $cellx = 0;
  my $x = 0;
  while ($x + $maxrectwidth <= $maxcols) {
    my $width = $minrectwidth
      + int rand($maxrectwidth - $minrectwidth);
    my $startx = $x;
    $x += $width;
    my $endx = $x;
    $cellcol[$cellx++] = +{
                           cellx  => $cellx,
                           startx => $startx,
                           stopx  => $startx + $width,
                          };
    $x++; # Don't overlap by one.
  }
  my ($y, $celly, $rect) = (0, 0, 0);
  while ($y + $maxrectheight <= $maxrows) {
    my $height = $minrectheight
      + int rand($maxrectheight - $minrectheight);
    my $starty = $y;
    $y += $height;
    my $endy = $y;
    $y++;
    my ($x, $cellx) = (0, 0);
    foreach my $cellcol (@cellcol) {
      my $width = $minrectwidth
        + int rand($maxrectwidth - $minrectwidth);
      my $startx = $x;
      $x += $width;
      my $endx = $x;
      $rect[$celly][$cellx] = +{
                                rect   => ++$rect,
                                celly  => $celly,
                                starty => $starty,
                                stopy  => $starty + $height,
                                maxy   => $maxrows,
                                maxx   => $maxcols,
                                miny   => 0,
                                minx   => 0,
                                map { $_ =>
                                        ${$cellcol[$cellx]}{$_}
                                      } qw(cellx startx stopx),
                               };
      $cellx++;
    }
    $celly++;
  }
}

if ($debug > 4) {
  my @stageone = buildlevel(@rect);
  #use Data::Dumper; print Dumper(\@rect);
  printlevel(level => \@stageone,
             title => "Stage One",
             debug => $debug,
            );
}
print "Minimum rect dimensions: $minrectheight,$minrectwidth\n"
  if $debug > 4;

# That's a start, but it's a bit too regular.  The cells in
# each row are the same height and line up at the top and
# bottom, and the cells in each column are the same width
# and line up at left and right.  To fix this, we want to
# push some of their borders around a bit.

# The trick is deciding which borders to push in a way that
# doesn't lead to overlapping.  If a cell is enlarged
# southward, for example, then the cell to the southwest
# cannot be enlarged eastward: its eastern side must be
# capped at a maximum that leaves it not overlapping.
# Similarly, the cell to the southeast will have its
# western edge limited.

# To support this, we introduce four new fields to each
# cell: minx, maxx, miny, maxy.  They will all start at
# undef, meaning the cell is limited only by its immediate
# neighbors (vertically and horizontally).  When a border
# is pushed, these limits will be checked first (to see
# if the push is allowed) and then adjusted after (to
# prevent subsequent pushes from overlapping).

# There are scalar @cellcol columns of cells, numbered from
# 0 to ((scalar @cellcol) - 1) and scalar @rect rows of
# cells, numberd from 0 to ((scalar @rect) - 1).  In order
# to prevents systematic bias, we want to consider these
# borders in random order.  To do that, we need a list:

my @border = (
              # Vertical borders:
              (map {
                my $y = $_; # y coord of second/bottom cell
                map {
                  my $x = $_; # x coord of both cells
                  +{
                    direction => 'y',
                    cellone   => [ $y - 1, $x ],
                    celltwo   => [ $y, $x ],
                   }
                } 0 .. ((scalar @cellcol) - 1);
              } 1 .. ((scalar @rect) - 1)),
              # Horizontal borders:
              (map {
                my $y = $_; # y coord of both cells
                map {
                  my $x = $_; # x coord of second/right cell
                  +{
                    direction => 'x',
                    cellone   => [ $y, $x - 1 ],
                    celltwo   => [ $y, $x ],
                   }
                } 1 .. ((scalar @cellcol) - 1);
              } 0 .. ((scalar @rect) - 1),
              ));
# Put that list in a random order:
@border = map {
  $$_[0]
} sort {
  $$a[1] <=> $$b[1]
} map {
  [ $_ => rand(1087) ]
} @border;
my @maybemerge;
# Now we got through the list of borders...
for my $border (@border) {
  my $oney = $$border{cellone}[0]; # This
  my $onex = $$border{cellone}[1]; # saves
  my $twoy = $$border{celltwo}[0]; # confusion
  my $twox = $$border{celltwo}[1]; # below.
  print "Considering border between cells $oney,$onex"
    . " and $twoy,$twox\n" if $debug > 6;
  if ($$border{direction} eq 'y') {
    # The two cells have different y coords, same x.
    if (rand(100)>= 50) {
      # Try to enlarge the first cell (shrink the second).
      print "  Want to grow south.\n" if $debug > 7;
      # First off, the second cell can't be shrunk to less
      # than the minimum height:
      my $twocurrentheight
        = $rect[$twoy][$twox]{stopy}
        - $rect[$twoy][$twox]{starty};
      my $maxshrink = $twocurrentheight - $minrectheight;
      print "  Maximum shrink calculated at $maxshrink.\n"
        if $debug > 9;
      my $maxy = $rect[$oney][$onex]{stopy} + $maxshrink;
      if ($rect[$oney][$onex]{maxy} > $maxy) {
        $rect[$oney][$onex]{maxy} = $maxy;
      } else {
        $maxy = $rect[$oney][$onex]{maxy};
      }
      my $maxgrow = $maxy - $rect[$oney][$onex]{stopy};
      print "  Maximum growth calculated at $maxgrow.\n"
        if $debug > 8;
      if ($maxgrow > 0) {
        my $grow = int rand($maxgrow) + 1;
        print "  Growing cell $oney,$onex south by $grow.\n"
          if $debug > 4;
        $rect[$oney][$onex]{stopy}  += $grow;
        $rect[$twoy][$twox]{starty} += $grow;
        push @maybemerge, $border
          if abs($grow) >= $mergethreshold;
        # Limit nearby cells so they won't overlap:
        if (($twox >= 1)
            and ($rect[$twoy][$twox - 1]{maxx}
                 >= $rect[$oney][$onex]{startx})) {
          $rect[$twoy][$twox - 1]{maxx} =
            $rect[$oney][$onex]{startx} - 1;
        }
        if (($twox + 1 < (scalar @cellcol))
            and ($rect[$twoy][$twox + 1]{minx}
                 <= $rect[$oney][$onex]{startx})) {
          $rect[$twoy][$twox + 1]{minx} =
            $rect[$oney][$onex]{startx} + 1;
        }
        if ($debug > 8) {
          my @stage = buildlevel(@rect);
          printlevel(level => \@stage,
                     title => "Growing Cell $oney,$onex South",
                     debug => $debug);
        }
      } elsif ($debug > 5) {
        print "  Cannot grow cell $oney,$onex south.\n";
        use Data::Dumper;
        print Dumper(+{
                       one => $rect[$oney][$onex],
                       two => $rect[$twoy][$twox],
                       max => $maxy,
                       cur => $twocurrentheight,
                      });
      }
    } else {
      # Try to enlarge the second cell (shrink the first).
      print "  Want to grow north.\n" if $debug > 7;
      # First off, the first cell can't be shrunk to less
      # than the minimum height:
      my $onecurrentheight
        = $rect[$oney][$onex]{stopy}
        - $rect[$oney][$onex]{starty};
      my $maxshrink = $onecurrentheight - $minrectheight;
      print "  Maximum shrink calculated at $maxshrink.\n"
        if $debug > 9;
      my $miny = $rect[$twoy][$twox]{starty} - $maxshrink;
      if ($rect[$twoy][$twox]{miny} < $miny) {
        $rect[$twoy][$twox]{miny} = $miny;
      } else {
        $miny = $rect[$twoy][$twox]{miny};
      }
      my $maxgrow = $rect[$twoy][$twox]{starty} - $miny;
      print "  Maximum growth calculated at $maxgrow.\n"
        if $debug > 8;
      if ($maxgrow > 0) {
        my $grow = int rand($maxgrow) + 1;
        print "  Growing cell $twoy,$twox north by $grow.\n"
          if $debug > 4;
        $rect[$oney][$onex]{stopy}  -= $grow;
        $rect[$twoy][$twox]{starty} -= $grow;
        # Limit nearby cells so they won't overlap:
        if (($onex >= 1)
            and ($rect[$oney][$onex - 1]{maxx}
                 >= $rect[$twoy][$twox]{startx})) {
          $rect[$oney][$onex - 1]{maxx} =
            $rect[$twoy][$twox]{startx} - 1;
        }
        if (($onex + 1 < (scalar @cellcol))
            and ($rect[$oney][$onex + 1]{minx}
                 <= $rect[$twoy][$twox]{startx})) {
          $rect[$oney][$onex + 1]{maxy} =
            $rect[$twoy][$twox]{startx} + 1;
        }
        if ($debug > 8) {
          my @stage = buildlevel(@rect);
          printlevel(level => \@stage,
                     title => "Growing Cell $twoy,$twox North",
                     debug => $debug);
        }
      } elsif ($debug > 5) {
        print "  Cannot grow cell $twoy,$twox north.\n";
        use Data::Dumper;
        print Dumper(+{
                       one => $rect[$oney][$onex],
                       two => $rect[$twoy][$twox],
                       min => $miny,
                       cur => $onecurrentheight,
                      });
      }
    }
  } elsif ($$border{direction} eq 'x') {
    # The two cells have different x coords, same y.
    if (rand(100)>= 50) {
      # Try to enlarge the first cell (shrink the second).
      print "  Want to grow east.\n" if $debug > 7;
      # First off, the second cell can't be shrunk to less
      # than the minimum width:
      my $twocurrentwidth
        = $rect[$twoy][$twox]{stopx}
        - $rect[$twoy][$twox]{startx};
      my $maxshrink = $twocurrentwidth - $minrectwidth;
      print "  Maximum shrink calculated at $maxshrink.\n"
        if $debug > 9;
      my $maxx = $rect[$oney][$onex]{stopx} + $maxshrink;
      # TODO: Not entirely sure but what catycorner rects
      #       should also be checked.
      if ($rect[$oney][$onex]{maxx} > $maxx) {
        $rect[$oney][$onex]{maxx} = $maxx;
      } else {
        $maxx = $rect[$oney][$onex]{maxx};
      }
      my $maxgrow = $maxx - $rect[$oney][$onex]{stopx};
      print "  Maximum growth calculated at $maxgrow.\n"
        if $debug > 8;
      if ($maxgrow > 0) {
        my $grow = int rand($maxgrow) + 1;
        print "  Growing cell $oney,$onex east by $grow.\n"
          if $debug > 4;
        $rect[$oney][$onex]{stopx}  += $grow;
        $rect[$twoy][$twox]{startx} += $grow;
        push @maybemerge, $border
          if abs($grow) >= $mergethreshold;
        # Limit nearby cells so they won't overlap:
        if (($twoy >= 1)
            and ($rect[$twoy - 1][$twox]{maxy}
                 >= $rect[$oney][$onex]{starty})) {
          $rect[$twoy - 1][$twox]{maxy} =
            $rect[$oney][$onex]{starty} - 1;
        }
        if (($twoy + 1 < (scalar @rect))
            and ($rect[$twoy + 1][$twox]{miny}
                 <= $rect[$oney][$onex]{stopy})) {
          $rect[$twoy + 1][$twox]{miny} =
            $rect[$oney][$onex]{stopy} + 1;
        }
        if ($debug > 8) {
          my @stage = buildlevel(@rect);
          printlevel(level => \@stage,
                     title => "Growing Cell $oney,$onex East",
                     debug => $debug);
        }
      } elsif ($debug > 5) {
        print "  Cannot grow cell $oney,$onex east.\n";
        use Data::Dumper;
        print Dumper(+{
                       one => $rect[$oney][$onex],
                       two => $rect[$twoy][$twox],
                       max => $maxx,
                       cur => $twocurrentwidth,
                      });
      }
    } else {
      # Try to enlarge the first cell (shrink the second).
      print "  Want to grow west.\n" if $debug > 7;
      # First off, the first cell can't be shrunk to less
      # than the minimum width:
      my $onecurrentwidth
        = $rect[$oney][$onex]{stopx}
        - $rect[$oney][$onex]{startx};
      my $maxshrink = $onecurrentwidth - $minrectwidth;
      print "  Maximum shrink calculated at $maxshrink.\n"
        if $debug > 9;
      my $minx = $rect[$twoy][$twox]{stopx} - $maxshrink;
      # TODO: Not entirely sure but what catycorner rects
      #       should also be checked.
      if ($rect[$twoy][$twox]{minx} < $minx) {
        $rect[$twoy][$twox]{minx} = $minx;
      } else {
        $minx = $rect[$twoy][$twox]{minx};
      }
      my $maxgrow = $rect[$twoy][$twox]{startx} - $minx;
      print "  Maximum growth calculated at $maxgrow.\n"
        if $debug > 8;
      if ($maxgrow > 0) {
        my $grow = int rand($maxgrow) + 1;
        print "Growing cell $twoy,$twox west by $grow.\n"
          if $debug > 4;
        $rect[$oney][$onex]{stopx}  -= $grow;
        $rect[$twoy][$twox]{startx} -= $grow;
        # Limit nearby cells so they won't overlap:
        if (($oney >= 1)
            and ($rect[$oney - 1][$onex]{maxy}
                 >= $rect[$twoy][$twox]{starty})) {
          $rect[$oney - 1][$onex]{maxy}
            = $rect[$twoy][$twox]{starty} - 1;
        }
        if (($oney + 1 < (scalar @rect))
            and ($rect[$oney + 1][$onex]{miny}
                <= $rect[$twoy][$twox]{starty})) {
          $rect[$oney + 1][$onex]{miny}
            = $rect[$twoy][$twox]{starty} + 1;
        }
        if ($debug > 8) {
          my @stage = buildlevel(@rect);
          printlevel(level => \@stage,
                     title => "Growing Cell $twoy,$twox West",
                     debug => $debug);
        }
      } elsif ($debug > 5) {
        print "  Cannot grow cell $twoy,$twox west.\n";
        use Data::Dumper;
        print Dumper(+{
                       one => $rect[$oney][$onex],
                       two => $rect[$twoy][$twox],
                       min => $minx,
                       cur => $onecurrentwidth,
                      });
      }}
  } else {
    die "Impossible border direction: '$$border{direction}'";
  }
}

if ($debug > 4) {
  my @stagetwo = buildlevel(@rect);
  printlevel(level => \@stagetwo,
             title => "Stage Two",
             debug => $debug);
}

# Combine a few adjacent rectangles if possible:
# Start by putting the list in a new random order:
print "There are " . @maybemerge
  . " cell pairs to consider merging.\n"
  if $debug > 2;
@maybemerge = map {
  $$_[0]
} sort {
  $$a[1] <=> $$b[1]
} map {
  [ $_ => rand(1087) ]
} @maybemerge;

for my $pair (@maybemerge) {
  my $oney = $$pair{cellone}[0]; # This
  my $onex = $$pair{cellone}[1]; # saves
  my $twoy = $$pair{celltwo}[0]; # confusion
  my $twox = $$pair{celltwo}[1]; # below.
  my $rone = $rect[$oney][$onex];
  my $rtwo = $rect[$twoy][$twox];
  if ((ref $rone) and (ref $rtwo)) {
    print "Considering merging cells $oney,$onex"
      . " and $twoy,$twox" if $debug > 6;
    if (rand(100)<= $mergeprob) {
      print ", decided to try.\n" if $debug > 6;
      if ($$border{direction} eq 'y') {
        # The two cells have different y coords, same x.
        my $newstartx = $$rone{startx};
        my $newstopx  = $$rone{stopx};
        $newstartx = $$rtwo{startx}
          if $$rtwo{startx} > $newstartx;
        $newstopx  = $$rtwo{stopx}
          if $$rtwo{stopx}  < $newstopx;
        if ($newstopx - $newstartx >= $minrectwidth) {
          my $newstarty = $$rone{starty};
          my $newstopy  = $$rtwo{starty};
          $rect[$oney][$onex] = +{
                                  rect   => $$rone{rect},
                                  celly  => $oney,
                                  twoy   => $twoy,
                                  cellx  => $onex,
                                  starty => $newstarty,
                                  stopy  => $newstopy,
                                  startx => $newstartx,
                                  stopx  => $newstartx,
                                  merged => 'y',
                                 };
          push @purged, $rect[$twoy][$twox];
          $rect[$twoy][$twox] = undef;
          print "Merged vertically: $newstarty,$newstartx"
            . " $newstopy,$newstopx.\n" if $debug >= 3;
        } else {
          print "New rect would not be wide enough "
            . "($newstopx - $newstartx < $minrectwidth).\n"
              if $debug > 6;
        }
      } else {
        # The two cells have different x coords, same y.
        my $newstarty = $$rone{starty};
        my $newstopy  = $$rone{stopy};
        $newstarty    = $$rtwo{starty}
          if $$rtwo{starty} > $newstarty;
        $newstopy     = $$rtwo{stopy}
          if $$rtwo{stopy}  < $newstopy;
        if ($newstopy - $newstarty >= $minrectheight) {
          my $newstartx = $$rone{startx};
          my $newstopx  = $$rtwo{stopx};
          $rect[$oney][$onex] = +{
                                  rect    => $$rone{rect},
                                  celly   => $oney,
                                  cellx   => $onex,
                                  twox    => $twox,
                                  starty  => $newstarty,
                                  stopy   => $newstopy,
                                  startx  => $newstartx,
                                  stopx   => $newstopx,
                                  merged  => 'x',
                                 };
          push @purged, $rect[$twoy][$twox];
          $rect[$twoy][$twox] = undef;
          print "Merged horizontally: $newstarty,$newstartx"
            . " $newstopy,$newstopx.\n" if $debug >= 3;
        } else {
          print "New rect would not be tall enough "
            . "($newstopy - $newstarty < $minrectheight.)\n"
              if $debug > 6;
        }
      }
    } else {
      print ", decided against it.\n" if $debug > 6;
    }
  }}

use Data::Dumper; print Dumper(+{ purged => \@purged })
  if $debug > 7;

my @finalstage = buildlevel(@rect);
printlevel(level => \@finalstage);

sub buildlevel {
  my @r = @_;
  my ($maxfloorx, $maxfloory) = (0,0);
  my @pos = map { # Initialize to blank:
    [ map { +{ char => $blankchar,
               terr => 'rock (by default)',
               colr => 'reset',
               furn => [],
               objs => [],
               mons => undef,
               rect => undef,
               room => undef,
             } } 1 .. $maxcols ],
  } 1 .. $maxrows;
  print "The pos array has " . @pos . "rows after init.\n"
    if $debug > 9;
  for my $celly ( 0 .. ((scalar @r) - 1)) {
    for my $cellx ( 0 .. ((scalar @cellcol) - 1)) {
      my $rect = $r[$celly][$cellx];
      if (ref $rect) {
        my $rdig = $$rect{rect} % 10;
        warn "Mismatch on celly" if $$rect{celly} ne $celly;
        warn "Mismatch on cellx" if $$rect{cellx} ne $cellx;
        # Step One: Assign Rectangle
        for my $y ($$rect{starty} .. $$rect{stopy}) {
          for my $x ($$rect{startx} .. $$rect{stopx}) {
            $pos[$y][$x]{rect} = $$rect{rect};
            $pos[$y][$x]{char} = $rdig if $debug > 12;
          }
        }
        if (rand(100)<=$roomprob) {
          # Step Two: Calculate Room Size and Position:
          my $rectwidth  = $$rect{stopx} - $$rect{startx};
          my $rectheight = $$rect{stopy} - $$rect{starty};
          # Leave room for at least one corridor tile:
          my $maxroomwidth  = $rectwidth - 1
            - int rand rand ($rectwidth - $minroomwidth);
          my $maxroomheight = $rectheight - 1
            - int rand rand ($rectheight - $minroomheight);
          my $roomwidth  = $maxroomwidth
            - int rand int rand ($maxroomwidth - $minroomwidth);
          my $roomheight = $maxroomheight
            - int rand int rand ($maxroomheight - $minroomheight);
          my $xslop = $rectwidth  - $roomwidth;
          my $yslop = $rectheight - $roomheight;
          my $roomstartx = $$rect{startx} + int rand $xslop;
          my $roomstarty = $$rect{starty} + int rand $yslop;
          my $roomstopx  = $roomstartx + $roomwidth;
          my $roomstopy  = $roomstarty + $roomheight;
          $r[$celly][$cellx]{roomgeom} = +{
                                           startx => $roomstartx,
                                           starty => $roomstarty,
                                           stopx  => $roomstopx,
                                           stopy  => $roomstopy,
                                           width  => $roomwidth,
                                           height => $roomheight,
                                          };
          # Step Three:  Place Floor
          my $fc = ($debug > 7) ? ($$rect{rect}%10) : $floorchar;
          for my $y (($roomstarty + 1) .. ($roomstopy - 1)) {
            for my $x (($roomstartx + 1) .. $roomstopx - 1) {
              $pos[$y][$x]{terr} = 'floor';
              $pos[$y][$x]{char} = $fc;
              $pos[$y][$x]{colr} = $floorcolor;
              $pos[$y][$x]{room} = $$rect{rect};
              $maxfloory = $y if $y > $maxfloory;
              $maxfloorx = $x if $x > $maxfloorx;
            }}
          # Step Four: Place Walls
          for my $y ($roomstarty .. $roomstopy) {
            for my $x ($roomstartx, $roomstopx) {
              $pos[$y][$x]{terr} = 'wall';
              $pos[$y][$x]{char} = $vertwallchar;
              $pos[$y][$x]{colr} = $wallcolor;
              $pos[$y][$x]{room} = $$rect{rect};
            }}
          for my $y ($roomstarty, $roomstopy) {
            for my $x ($roomstartx .. $roomstopx) {
              $pos[$y][$x]{terr} = 'wall';
              $pos[$y][$x]{char} = $horizwallchar;
              $pos[$y][$x]{colr} = $wallcolor;
              $pos[$y][$x]{room} = $$rect{rect};
            }}
          $pos[$roomstarty][$roomstartx]{char} = $nwcornerchar;
          $pos[$roomstarty][$roomstopx]{char}  = $necornerchar;
          $pos[$roomstopy][$roomstartx]{char}  = $swcornerchar;
          $pos[$roomstopy][$roomstopx]{char}   = $secornerchar;
          $pos[$roomstarty][$roomstartx]{crnr} = 1;
          $pos[$roomstarty][$roomstopx]{crnr}  = 1;
          $pos[$roomstopy][$roomstartx]{crnr}  = 1;
          $pos[$roomstopy][$roomstopx]{crnr}   = 1;
        } else {
          $r[$celly][$cellx]{roomgeom} = undef;
        }}
    }}
  my @roomcell = sort { $$a[2] <=> $$b[2] } map {
    my $celly = $_;
    map {
      my $cellx = $_;
      [$celly, $cellx, rand(739)];
    } 0 .. ((scalar @cellcol) - 1);
  } 0 .. ((scalar @r) - 1);
  # Step Five: Place Contents:
  {
  my ($didup, $diddown) = (0, 0);
  my ($fountcount, $sinkcount, $altarcount, $gravecount,
      $poolcount, $lavacount) = (0, 0, 0, 0, 0, 0);
  for my $cell (@roomcell) {
    my ($celly, $cellx) = @$cell;
    my $rect = $r[$celly][$cellx];
    if (ref $rect) {
      print " R$$rect{rect}" if $debug > 13;
      my ($roomfountcount, $roomsinkcount,
          $roompoolcount, $roomlavacount) = (0, 0, 0, 0);
      # Step 5A: Place Furniture
      my $special;
      if (not $didup) {
        $didup = placefurniture(\@r, \@pos, $celly, $cellx,
                                'stairs', '<', $upstaircolor);
        if ($didup and ($debug > 6)) {
          print color $staircolor;
          print '<';
          print color 'reset';
        }
      } elsif (not $diddown) {
        $diddown = placefurniture(\@r, \@pos, $celly, $cellx,
                                  'stairs', '>', $downstaircolor);
        if ($diddown and ($debug > 6)) {
          print color $staircolor;
          print '>';
          print color 'reset';
        }
      } else {
        if (rand(100)<=$specialprob) {
          $special = 'statue hall'; # Default
          if (rand(100)<=60) {
            $special = 'dragon lair';
          } # TODO: more special-room options
        }}
      if ($special eq 'statue hall') {
        my @bordertile;
        my $statuecount;
        push @bordertile, $_ for map {
          my $x = $_;
          [$$rect{roomgeom}{starty} + 1, $x]
        } ($$rect{roomgeom}{startx} + 1)
          .. ($$rect{roomgeom}{stopx} - 1);
        push @bordertile, $_ for map {
          my $y = $_;
          [$y, $$rect{roomgeom}{stopx} - 1]
        } ($$rect{roomgeom}{starty} + 2)
          .. ($$rect{roomgeom}{stopy} - 2);
        push @bordertile, $_ for map {
          my $x = $_;
          [$$rect{roomgeom}{stopy} - 1, $x]
        } reverse (($$rect{roomgeom}{startx} + 1)
                   .. ($$rect{roomgeom}{stopx} - 1));
        push @bordertile, $_ for map {
          my $y = $_;
          [$y, $$rect{roomgeom}{startx} + 1]
        } reverse (($$rect{roomgeom}{starty} + 2)
                   .. ($$rect{roomgeom}{stopy} - 2));
        my $spacing = (defined $statuespacing)
          ? $statuespacing : ((int rand(5)) ? 1 : rand(3));
        while (scalar @bordertile) {
          my $tile = shift @bordertile;
          placefurniture(\@r, \@pos, $celly, $cellx,
                         'statue', $statuechar,
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
        placemonster(\@r, \@pos, $celly, $cellx,
                     "great $color dragon",
                     'D', $dragoncolor{$color});
        placemonster(\@r, \@pos, $celly, $cellx,
                     "$color dragon", 'D', $dragoncolor{$color})
          for 1 .. (2 + int rand 3);
        placemonster(\@r, \@pos, $celly, $cellx,
                     "baby $color dragon",
                     'D', $dragoncolor{$color})
          for 1 .. (3 + int rand 4);
        # TODO: place gold and gems and thematic stuff
      #} elsif ($special eq 'another option') { # TODO
      } else {
        while ((rand(100) <= $fountainprob) and
               ($fountcount < $maxfountains) and
               ($roomfountcount < $maxroomfounts)) {
          if (placefurniture(\@r, \@pos, $celly, $cellx,
                             'fountain', $fountainchar,
                             $fountaincolor)) {
            $fountcount++; $roomfountcount++;
            if ($debug > 6) {
              print color $fountaincolor;
              print $fountainchar;
              print color 'reset';
            }
          }}
        while ((rand(100) <= $sinkprob) and
               ($sinkcount < $maxsinks) and
               ($roomsinkcount < $maxroomsinks)) {
          if (placefurniture(\@r, \@pos, $celly, $cellx,
                             'sink', $sinkchar, $sinkcolor)) {
            $sinkcount++; $roomsinkcount++;
            if ($debug > 6) {
              print color $sinkcolor;
              print $sinkchar;
              print color 'reset';
            }
          }}
        if ((rand(100) <= $altarprob) and
            ($altarcount < $maxaltars)) {
          if (placefurniture(\@r, \@pos, $celly, $cellx,
                             'altar', $altarchar, $altarcolor)) {
            $altarcount++;
            if ($debug > 6) {
              print color $altarcolor;
              print $altarchar;
              print color 'reset';
            }
            if (rand(100) <= $priestprob) {
              placemonster(\@r, \@pos, $celly, $cellx,
                           'aligned priest',
                           $priestchar, $priestcolor);
              if ($debug > 6) {
                print color $priestcolor;
                print $priestchar;
                print color 'reset';
              }}
          }}
        if ((rand(100) <= $graveprob) and
            ($gravecount < $maxgraves)) {
          if (placefurniture(\@r, \@pos, $celly, $cellx,
                             'grave', $gravechar, $gravecolor)) {
            $gravecount++;
            if ($debug > 6) {
              print color $gravecolor;
              print $gravechar;
              print color 'reset';
            }
          }}
        # Step 5B: Terrain Features:
        while ((rand(100) <= ($roompoolcount
                              ? $morepoolprob
                              : $poolprob))
               and ($poolcount < $maxpools)
               and ($roompoolcount < $maxroompools)) {
          if (placefurniture(\@r, \@pos, $celly, $cellx,
                             'pool', $poolchar,
                             $poolcolor)) {
            $poolcount++; $roompoolcount++;
            if ($debug > 6) {
              print color $poolcolor;
              print $poolchar;
              print color 'reset';
            }
          }}
        while ((rand(100) <= ($roomlavacount
                              ? $morelavaprob
                              : $lavaprob))
               and (lavacount < $maxlava)
               and ($roomlavacount < $maxroomlava)
               and (not $roompoolcount)
               and (not $roomfountcount)
               and (not $roomsinkcount)) {
          if (placefurniture(\@r, \@pos, $celly, $cellx,
                             'lava', $lavachar,
                             $lavacolor)) {
            $lavacount++; $roomlavacount++;
            if ($debug > 6) {
              print color $lavacolor;
              print $lavachar;
              print color 'reset';
            }
          }}
        my $roommonstcount = 0;
        while (rand(100) <= ($roommonstcount
                             ? $moremonstprob
                             : $monsterprob)) {
          my ($mtype, $mchar, $mcolor)
            = @{$randmonst[int rand @randmonst]};
          $roommonstcount++
            if placemonster(\@r, \@pos, $celly, $cellx,
                            $mtype, $mchar, $mcolor);
          if (rand(100)<= $mongroupprob) {
            for (1 .. int rand $maxgroupsize) {
              if ($roommonstcount <= $maxroommonst) {
                $roommonstcount++
                  if placemonster(\@r, \@pos, $celly, $cellx,
                                  $mtype, $mchar, $mcolor);
              }}}
        }
        # Step 5D: Place Objects
      }}}
  }
  # Step Six: Place Corridors (including doors)
  print "The pos array has " . @pos . "rows before corridors.\n"
    if $debug > 9;
  for my $celly ( 0 .. ((scalar @r) - 1)) {
    for my $cellx ( 0 .. ((scalar @cellcol) - 1)) {
      my $rect = $r[$celly][$cellx];
      if (ref $$rect{roomgeom}) {
        my $geom = $$rect{roomgeom};
        print "Cell $celly,$cellx" if $debug > 10;
        my @conn, %conn, $attempt;
        my $cwanted = 1 + int rand $corridorfreq;
        print " ($cwanted) " if $debug > 14;
        while ($cwanted > scalar @conn) {
          my ($xdir, $ydir, $origin) = (0, 0, +{});
          my $secret = (rand(100) <= $secretprob) ? 1 : 0;
          my @save = @pos;
          print "*" if $debug > 11;
          my $originok = 0;
          my ($origindir, $origintry);
          my ($floorwidth, $floorheight);
          while ((not $originok) and ($origintry++ < 80)) {
            while ((($xdir == 0) and ($ydir == 0))
                   or ($xdir and $ydir) ) {
              $xdir = (int rand(3)) - 1;
              $ydir = (int rand(3)) - 1;
            }
            print "<$ydir,$xdir>:" if $debug > 13;
            $origindir =
              (not $xdir)
                ? 'vert'
                : (not $ydir)
                  ? 'horz'
                  : (rand(100) >= 50) ? 'vert' : 'horz';
            if ($origindir eq 'vert') {
              # origin must be top or bottom
              $$origin{y} = ($ydir > 0)
                ? $$geom{stopy}
                : $$geom{starty};
              $floorwidth = $$geom{width} - 2;
              $$origin{x} = $$geom{startx} + 1
                + int rand $floorwidth;
            } else {
              # origin must be on the side
              $$origin{x} = ($xdir > 0)
                ? $$geom{stopx}
                : $$geom{startx};
              $floorheight = $$geom{height} - 2;
              $$origin{y} = $$geom{starty} + 1
                + int rand $$floorheight;
            }
            # Is that origin OK?  Note that we don't want to
            # allow origin at map edge.
            $originok = 1;
            # Do not allow origin at map edge:
            if ((($celly == 0) and ($origindir eq 'vert')
                 and ($ydir <= 0))
                or (($cellx == 0) and ($origindir eq 'horz')
                    and ($xdir <= 0))
               ) {
              $originok = 0;
              print "#" if $debug > 12;
            } elsif (($origindir eq 'vert')
                     and ($celly == ((scalar @r) - 1))) {
              $originok = 0 if $ydir >= 0;
            } elsif (($origindir eq 'horz')
                     and ($cellx == ((scalar @cellcol) - 1))) {
              $originok = 0 if $xdir >= 0;
            }}
          print "cell $celly,$cellx; o$origintry $origindir"
            . "($$origin{y},$$origin{x}) $ydir,$xdir\n"
              if $debug > 10;
          if ($originok) {
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
            } else {
              $pos[$$origin{y}][$$origin{x}]{char} =
                $secret ? $sdoorchar : $doorchar;
              $pos[$$origin{y}][$$origin{x}]{colr} =
                $secret ? $sdoorcolor : $doorcolor;
              $pos[$$origin{y}][$$origin{x}]{terr} = 'door';
            }
            my $x = $$origin{x};
            my $y = $$origin{y};
            my $connected = undef;
            while (not $connected) {
              my ($oldxdir, $oldydir) = ($xdir, $ydir);
              print "." if $debug > 12;
              if (rand(100) <= $corridortwist) {
                $xdir = int rand(3) - 1;
                $ydir = int rand(3) - 1;
              }
              my $loopcount = 0;
              while ((($x + $xdir < 0) or
                      ($x + $xdir > $maxfloorx + 1) or
                      ($y + $ydir < 0) or
                      ($y + $ydir > $maxfloory + 1) or
                      (($xdir == 0) and ($ydir == 0)) or
                      (($oldxdir + $xdir == 0) and
                       ($oldydir + $ydir == 0)) or
                      ($pos[$y + $ydir][$x + $xdir]{crnr})
                     ) and ($loopcount++ < 1000)) {
                print "x$x,y$y,xdir$xdir,ydir$ydir,"
                  ."oldxdir$oldxdir,oldydir$oldydir"
                    if ($loopcount == 999 and $debug > 10);
                $xdir = int rand(3) - 1;
                $ydir = int rand(3) - 1;
              }
              if ($xdir and $ydir) {
                # When doing diagonals, attempt to fill in
                # an adjascent tile, to reduce the need for
                # squeezing through tight spaces:
                if (rand(100)<=60) {
                  # Try for an adjacent tile horizontally:
                  if ($pos[$y + $ydir][$x]{char} eq $blankchar
                      #and $pos[$y + $ydir][$x]{terr} =~ /^blank/
                     ) {
                    $pos[$y + $ydir][$x]{terr} = 'hall';
                    $pos[$y + $ydir][$x]{char} = $corridorchar;
                    $pos[$y + $ydir][$x]{colr} =
                      ($debug > 9) ? 'red' : $corridorcolor;
                  }
                } else {
                  # Try for an adjacent tile vertically:
                  if ($pos[$y][$x + $xdir]{char} eq $blankchar
                      #and $pos[$y + $ydir][$x]{terr} =~ /^blank/
                     ) {
                    $pos[$y][$x + $xdir]{terr} = 'hall';
                    $pos[$y][$x + $xdir]{char} = $corridorchar;
                    $pos[$y][$x + $xdir]{colr} =
                      ($debug > 9) ? 'green' : $corridorcolor;
                  }
                }
              }
              warn "!" if ($loopcount >= 1000 and $debug > 2);
              $x += $xdir;
              $y += $ydir;
              if (($y > $maxrows) or ($x > $maxcols)) {
                warn "\n------------------------"
                  . "y$y,x$x,ydir$ydir,xdir$xdir\n"
                    if $debug > 4;
                @pos = @save;
                $connected = 1;
                push @conn, 'edge'
                  if not ++$attempt % $connectretry;
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
                } else {
                  $pos[$y][$x]{terr} = 'door';
                  $pos[$y][$x]{char} =
                    $secret ? $sdoorchar : $doorchar;
                  $pos[$y][$x]{colr} =
                    $secret ? $sdoorcolor : $doorcolor;
                }
                my $toroom = $pos[$y][$x]{room};
                if (not $conn{$$rect{rect}}{$toroom}) {
                  # We've connected to a new room.
                  $conn{$$rect{rect}}{$toroom}++;
                  $conn{$toroom}{$$rect{rect}}++;
                  push @conn, $toroom;
                  $connected = 1;
                  print "N" if $debug > 12;
                } else {
                  # We've connected to an already-connected room.
                  $connected = 1;
                  push @conn, 'dupe' if not ++$attempt % $connectretry;
                  print "R" if $debug > 12;
                }
              } elsif ($pos[$y][$x]{terr} eq 'hall') {
                $connected = 1;
                push @conn, 'fail' if not ++$attempt % $connectretry;
              } elsif ($pos[$y][$x]{terr} =~ /^rock/) {
                $pos[$y][$x]{terr} = 'hall';
                $pos[$y][$x]{char} = $corridorchar;
                $pos[$y][$x]{colr} = $corridorcolor;
              } else {
                warn "Unhandled terrain type: '$pos[$y][$x]{terr}'";
                $connected = 1; push @conn, 'Error';
              }
            }}
        }}
      print "\n" if $debug > 10;
    }}
  return @pos;
}

sub placeonfloor {
  my ($rect, $grid) = @_;
  my $miny = $$rect{roomgeom}{starty} + 1;
  my $minx = $$rect{roomgeom}{startx} + 1;
  my $maxy = $$rect{roomgeom}{stopy}  - 1;
  my $maxx = $$rect{roomgeom}{stopx}  - 1;
  print "[[$miny,$minx;$maxy,$maxx]]" if $debug > 8;
  my $tried = 0;
  while ($tried++ < 25) {
    my $y = $miny + (int rand($maxy + 1 - $miny));
    my $x = $minx + (int rand($maxx + 1 - $minx));
    print "[$y,$x]" if $debug > 30;
    if ($$grid[$y][$x]{terr} eq 'floor') {
      return ($y, $x);
    }}
  return ($miny, $minx);
}

sub placefurniture {
  my ($rects, $grid, $celly, $cellx, $terrain, $char, $colr, $y, $x) = @_;
  my @r = @$rects;
  my $rect = $r[$celly][$cellx];
  if (ref $rect) {
    if (ref $$rect{roomgeom}) {
      ($y, $x) = placeonfloor($rect, $grid) if not defined $x;
      if ($$grid[$y][$x]{terr} eq 'floor') {
        $$grid[$y][$x]{terr} = $terrain || 'ERROR';
        $$grid[$y][$x]{char} = $char || $errorchar;
        $$grid[$y][$x]{colr} = $colr || $errorcolor;
        push @{$$grid[$y][$x]{furn}}, +{
                                        y    => $y,
                                        x    => $x,
                                        type => $terrain,
                                       };
        if ($debug > 8) {
          print "[$y,$x,$char]";
        }
        return [$y, $x];
      } else {
        print "<$$grid[$y][$x]{terr}>" if $debug > 30;
      }
      if ($debug > 8) {
        print "N";
        return;
      }
    } else {
      print "X" if $debug > 8;
      return;
    }
  } else {
    print "-" if $debug > 8;
    return;
  }
}
sub placemonster {
  my ($rects, $grid, $celly, $cellx, $type, $char, $colr) = @_;
  my @r = @$rects;
  my $rect = $r[$celly][$cellx];
  if (ref $rect) {
    if (ref $$rect{roomgeom}) {
      my $tried = 0;
      while ($tried++ < 15) {
        # Only place one monster per tile:
        my ($y, $x) = placeonfloor($rect, $grid);
        print "[$y,$x]" if $debug > 30;
        if (($$grid[$y][$x]{terr} eq 'floor') and
            (not ref $$grid[$y][$x]{mons})){
          $$grid[$y][$x]{mons} = +{
                                   char => $char || $errorchar,
                                   type => $type || 'MONSTER',
                                   colr => $colr || 'reset',
                                  };
          if ($debug > 8) {
            print "[$y,$x,$char]";
          }
          return [$y, $x];
        } else {
          print "<$$grid[$y][$x]{terr}>" if $debug > 30;
        }
      }
      if ($debug > 8) {
        print "N";
        return;
      }
    } else {
      print "X" if $debug > 8;
      return;
    }
  } else {
    print "-" if $debug > 8;
    return;
  }
}

sub rectcolor {
  my ($n) = @_;
  my @clr = ('white on_black', 'white on_blue',
             'white on_red',   'white on_cyan',
             'white on_green', 'white on_magenta',
             'black on_white', 'black on_yellow');
  while (((scalar @clr) > 1)
         and (not ((scalar @cellcol) % (scalar @clr)))
         ) {
    #warn "cell columns: " . scalar @cellcol;
    #warn "colors is a factor: " . scalar @clr;
    pop @clr;
  }
  #use Data::Dumper; print Dumper(\@clr); exit 0;
  return $clr[$n % (scalar @clr)];
}

sub printlevel {
  my (%a) = @_;
  my @p = @{$a{level}};
  print color 'reset';
  print "\n";
  if ($a{title}) {
    my $spaces = int(($maxcols - (length $a{title})) / 2);
    print " " x $spaces;
    print "$a{title}\n\n";
  }
  for my $row (@p) {
    for my $cell (@$row) {
      if (ref $$cell{mons}) {
        print color $$cell{mons}{colr} if $$cell{mons}{colr};
        print $$cell{mons}{char};
      #} elsif ($$cell{objs}) { # TODO
      } else {
        if ($a{debug} or ($debug > 3)) {
          print color rectcolor($$cell{rect});
        } else {
          print color $$cell{colr} if $$cell{colr};
        }
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
