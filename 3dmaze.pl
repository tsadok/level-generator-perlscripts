#!/usr/bin/perl -w
# -*- cperl -*-

use strict;
use utf8;
use Carp;
use open ':encoding(UTF-8)';
use open ":std";
require "./fixwalls.pl";

my %input = @ARGV;
my $xmax = $input{xmax} || 28;
my $ymax = $input{ymax} || 15;
my $zmax = $input{zmax} ||  3;
$input{minconnectprob} = 1 if not defined $input{minconnectprob};
$input{maxconnectprob} ||= 45;
$input{barprob} = 5 if not defined $input{barprob};
$input{secretprob} = 5 if not defined $input{secretprob};

my %mazedir = ( u => [ 0,  0, -1, "d"],
                d => [ 0,  0,  1, "u"],
                n => [ 0, -1,  0, "s"],
                e => [ 1,  0,  0, "w"],
                s => [ 0,  1,  0, "n"],
                w => [-1,  0,  0, "e"],
              );

my $reset      = chr(27) . qq{[0m};
my $underlined = chr(27) . qq{[4m};

#           name       bgr  bgg   bgb    fgr  fgg  fgb
my %clr = ( black    => [  0,   0,   0,    111, 111, 111],
            red      => [ 96,   0,   0,    255, 111, 111],
            green    => [  0,  96,   0,    127, 255, 127],
            blue     => [  0,   0,  96,    127, 175, 255],
            white    => [144, 144, 144,    255, 255, 255],
            yellow   => [148, 144,   0,    255, 250, 175],
            cyan     => [  0,  96,  96,     96, 255, 255],
            purple   => [ 96,   0, 127,    175,  48, 255],
            orange   => [175,  96,  48,    255, 159,  48],
            pink     => [127,  48,  75,    255, 159, 175],
            tertiary => [ 41,  77,  74,    255, 230, 188],
          );
listcolors() if $input{listcolors};

$|=1;

my $map = three_d_maze($xmax, $ymax, $zmax);
showmap($map);

exit 0; # Subroutines follow.

sub inbounds {
  my ($x, $y, $z, $xmax, $ymax, $zmax) = @_;
  return if $x < 1;
  return if $x > $xmax;
  return if $y < 1;
  return if $y > $ymax;
  return if $z < 1;
  return if $z > $zmax;
  return "in bounds";
}

sub three_d_maze_combine_groups {
  my ($maze, $xsize, $ysize, $zsize, $oldgroup, $newgroup) = @_;
  for my $x (1 .. $xsize) {
    for my $y (1 .. $ysize) {
      for my $z (1 .. $zsize) {
        if ($$maze[$x][$y][$z]{grp} eq $oldgroup) {
          $$maze[$x][$y][$z]{grp} = $newgroup;
        }
      }}}
}

sub three_d_maze_count_groups {
  my ($maze, $xsize, $ysize, $zsize) = @_;
  my $maxgroups = (($xsize + 1) * ($ysize + 1) * ($zsize + 1));
  my @membercount = map { 0 } (0 .. $maxgroups);
  my $count = 0;
  for my $x (1 .. $xsize) {
    for my $y (1 .. $ysize) {
      for my $z (1 .. $zsize) {
        $membercount[$$maze[$x][$y][$z]{grp}]++;
      }}}
  for my $m (1 .. $maxgroups) {
    ++$count if $membercount[$m] > 0;
  }
  #print "[$count groups: " . (join " ", @membercount) . "]";
  return $count;
}

sub three_d_maze_helper {
  my ($xsize, $ysize, $zsize) = @_;
  my $g = 1;
  my $maze = [map { [map { [map { +{ grp => $g++, map { $_ => 0 } keys %mazedir } } 0 .. $zsize] } 0 .. $ysize] } 0 .. $xsize];
  my @mdir = keys %mazedir;
  my %gseen = ();
  while ($g > 1) {
    for my $x (randomorder(1 .. $xsize)) {
      for my $y (randomorder(1 .. $ysize)) {
        for my $z (randomorder(1 .. $zsize)) {
          my $cprob = ($gseen{$$maze[$x][$y][$z]{grp}}++)
            ? ($input{minconnectprob} + int($input{maxconnectprob} / 2)) : $input{maxconnectprob};
          my $r = rand 100;
          if ($cprob > $r) {
            my $d = $mdir[int rand @mdir];
            my ($dx, $dy, $dz, $odir) = @{$mazedir{$d}};
            if (inbounds($x + $dx, $y + $dy, $z + $dz, $xsize, $ysize, $zsize)) {
              if (($$maze[$x][$y][$z]{grp} ne $$maze[$x+$dx][$y+$dy][$z+$dz]{grp}) or
                  $input{minconnectprob} > $r) {
                #print "Connecting ($x,$y,$z) to ($x+$dx,$y+$dy,$z+$dz).\n";
                $$maze[$x][$y][$z]{$d}++;
                $$maze[$x+$dx][$y+$dy][$z+$dz]{$odir}++;
                three_d_maze_combine_groups($maze, $xsize, $ysize, $zsize,
                                            $$maze[$x][$y][$z]{grp},
                                            $$maze[$x+$dx][$y+$dy][$z+$dz]{grp});
            }}}}}}
    $g = three_d_maze_count_groups($maze, $xsize, $ysize, $zsize);
    #print "[$g]";<STDIN>;
  }
  return $maze;
}

sub three_d_maze {
  my ($xsize, $ysize, $zsize) = @_;
  my $map = [map { [ map { [map { terrain("UNDECIDED") } 0 .. $zsize]; } 0 .. $ysize + 1]; } 0 .. $xsize + 1];
  for my $x (1, $xsize) {
    for my $y (0 .. $ysize + 1) {
      for my $z (0 .. $zsize) {
        $$map[$x][$y][$z] = terrain("EDGE");
      }}}
  for my $y (1, $ysize) {
    for my $x (0 .. $xsize + 1) {
      for my $z (0 .. $zsize) {
        $$map[$x][$y][$z] = terrain("EDGE");
      }}}
  my $mazexsize = int(($xsize - 1) / 3);
  my $mazeysize = int(($ysize - 1) / 2);
  my $maze = three_d_maze_helper($mazexsize, $mazeysize, $zsize);
  #use Data::Dumper; print Dumper(+{ maze => $maze });
  for my $mx (1 .. $mazexsize) {
    for my $my (1 .. $mazeysize) {
      for my $mz (1 .. $zsize) {
        my ($x, $y, $z) = (($mx - 1) * 3 + 1, ($my - 1) * 2 + 1, $mz);
        $$map[$x + 1][$y + 1][$z] = terrain("NODE");
        $$map[$x + 2][$y + 1][$z] = terrain("NODE");
          for my $dir (keys %mazedir) {
          my ($dx, $dy, $dz) = @{$mazedir{$dir}};
          #print "maze[$mx][$my][$mz]{$dir}\n";
          if ($$maze[$mx][$my][$mz]{$dir}) {
            if ($dz) {
              $$map[$x + 1 + (((int($y/2) + $z + (($dz > 0) ? 1 : 0)) % 2) ? 0 : 1)][$y + 1][$z] =
                terrain(($dz > 0) ? "DOWNSTAIR" : "UPSTAIR");
            }
            if ($dy) {
              for my $xoffset (1 .. 2) {
                $$map[$x + $xoffset][$y + 1 + $dy][$z] = terrain("FLOOR");
              }
            }
            if ($dx) {
              $$map[$x + (($dx > 0) ? 3 : 0)][$y + 1][$z] = terrain("FLOOR");
            }}}}}}
  for my $x (1 .. $xsize) {
    for my $y (1 .. $ysize) {
      for my $z (1 .. $zsize) {
        if ($$map[$x][$y][$z]{type} eq "UNDECIDED") {
          if (($x <= ($mazexsize - 1) * 3 + 3) and
              ($y <= ($mazeysize - 1) * 2 + 2)) {
            if ($input{barprob} > rand 100) {
              $$map[$x][$y][$z] = terrain("BARS");
            } elsif ($input{secretprob} > rand 100) {
              $$map[$x][$y][$z] = terrain("SCORR");
            } else {
              $$map[$x][$y][$z] = terrain("WALL");
            }
          } else {
            $$map[$x][$y][$z] = terrain("WALL");
          }
        }
      }
    }
  }
  # Now place the branch stairs (entrance/exit):
  for my $exit ([1, "UPEXIT"], [$zsize, "DOWNEXIT"]) {
    my ($z, $t) = @$exit;
    my ($x, $y, $tries) = (0,0,1000);
    while ((($x < 2) or ($x >= $xsize) or
            ($y < 2) or ($y >= $ysize) or
            ($$map[$x][$y][$z]{type} ne "FLOOR")) and
           ($tries-- > 0)) {
      $x = 1 + int rand $xsize;
      $y = 1 + int rand $ysize;
    }
    $$map[$x][$y][$z] = terrain($t);
  }
  return three_d_fixwalls($map, $xsize + 1, $ysize + 1, $zsize);
}

sub three_d_fixwalls {
  my ($map, $xsize, $ysize, $zsize) = @_;
  my @level = map {
    my $z = $_;
    fixwalls([map { my $x = $_;
                    [map { $$map[$x][$_][$z] } 0 .. $ysize]
                  } 0 .. $xsize],
             $xmax, $ymax,
             checkstone => 1);
  } 0 .. $zsize;
  for my $z (1 .. $zsize) {
    for my $x (1 .. $xsize) {
      for my $y (1 .. $ysize) {
        $$map[$x][$y][$z] = $level[$z]->[$x][$y];
      }
    }
  }
  return $map;
}

sub terrain {
  my ($key) = @_;
  my %t = ( UNDECIDED => +{ bg   => "tertiary",
                            fg   => "tertiary",
                            char => "?",
                            type => "UNDECIDED",
                          },
            EDGE      => +{ bg   => "black",
                            fg   => "black",
                            char => " ",
                            type => "WALL",
                            pass => "no",
                          },
            STONE     => +{ bg   => "black",
                            fg   => "white",
                            char => " ",
                            type => "STONE",
                          },
            WALL      => +{ bg   => "black",
                            fg   => "orange",
                            char => "-",
                            type => "WALL",
                          },
            ERROR     => +{ bg   => "red",
                            fg   => "yellow",
                            char => "E",
                            type => "ERROR",
                          },
            DOWNSTAIR => +{ bg   => "red",
                            fg   => "white",
                            char => ">",
                            type => "STAIR",
                          },
            UPSTAIR   => +{ bg   => "red",
                            fg   => "white",
                            char => "<",
                            type => "STAIR",
                          },
            DOWNEXIT  => +{ bg   => "red",
                            fg   => "yellow",
                            char => $underlined . ">" . $reset,
                            type => "STAIR",
                          },
            UPEXIT    => +{ bg   => "red",
                            fg   => "yellow",
                            char => $underlined . "<" . $reset,
                            type => "STAIR",
                          },
            NODE      => +{ bg   => "black",
                            fg   => "white",
                            char => "·",
                            type => "FLOOR",
                          },
            FLOOR     => +{ bg   => "black",
                            fg   => "white",
                            char => "·",
                            type => "FLOOR",
                          },
            BARS      => +{ bg   => "black",
                            fg   => "cyan",
                            char => "#",
                            type => "IRONBARS",
                          },
            SCORR     => +{ bg   => "black",
                            fg   => "black",
                            char => "#",
                            type => "SCORR",
                          },
          );
  if (not ref $t{$key}) {
    die "No such terrain type: '$key'.";
    $key = "ERROR";
  }
  return +{ %{$t{$key}} };
}

sub showmap {
  my ($map) = @_;
  #use Data::Dumper; print Dumper(+{ map => $map });
  for my $z (1 .. $zmax) {
    if ($z == 1) {
      print "Top Level:\n";
    } elsif ($z == $zmax) {
      print "Bottom Level:\n";
    } else {
      print "Level $z:\n";
    }
    for my $y (1 .. $ymax) {
      for my $x (1 .. $xmax) {
        my $t = $map->[$x][$y][$z];
        print clr($$t{bg}, "bg") . clr($$t{fg}) . $$t{char};
      }
      print $reset . "\n";
    }
  }
}

sub randomorder {
  return map { $$_[0] } sort { $$a[1] <=> $$b[1] } map { [ $_ => rand 1000 ] } @_;
}

sub listcolors {
  my @c = keys %clr;
  print map { clr($_, "isbg") . clr($_) . " $_ " } keys %clr;
  print $reset . "\n";
  for my $bg (@c) {
    print map { clr($bg, "isbg") . clr($_) . " $_ " } keys %clr;
    print $reset . " (on $bg)\n";
  }
  print "\n";
}

sub clr {
  my ($key, $isbg) = @_;
  if ($clr{$key}) {
    my $type = $isbg ? 0 : 3;
    return rgb($clr{$key}[$type + 0], $clr{$key}[$type + 1], $clr{$key}[$type + 2], $isbg);
  } else {
    carp "No such color: $key";
  }
}

sub rgb { # Return terminal code for a 24-bit color.
  my ($red, $green, $blue, $isbg) = @_;
  my $fgbg = ($isbg) ? 48 : 38;
  my $delimiter = ";";
  return "\x1b[$fgbg${delimiter}2${delimiter}${red}"
    . "${delimiter}${green}${delimiter}${blue}m";
}
