#!/usr/bin/perl -w
# -*- cperl -*-

use strict;

sub fixwalls {
  my ($map, $xmax, $ymax, %arg) = @_;
  $arg{unicode} = "by default" if not exists $arg{unicode};
  my @wallglyph = ($arg{isolatedwallchar}                     || $arg{wallchar} || "-",                    #  0 => does not connect
                   $arg{hwallcharwestend}  || $arg{hwallchar} || $arg{wallchar} || ($arg{unicode} ? "─" : "-"), #  1 => connects east
                   $arg{vwallcharsouthend} || $arg{vwallchar} || $arg{wallchar} || ($arg{unicode} ? "│" : "|"), #  2 => connects north
                   $arg{swcorner}                             || $arg{wallchar} || ($arg{unicode} ? "└" : "-"), #  3 = 1 + 2 => connects east and north
                   $arg{hwallchareastend}  || $arg{hwallchar} || $arg{wallchar} || ($arg{unicode} ? "─" : "-"), #  4 => connects west
                   $arg{hwallchar}                            || $arg{wallchar} || ($arg{unicode} ? "─" : "-"), #  5 = 1 + 4 => connects east and west
                   $arg{secorner}                             || $arg{wallchar} || ($arg{unicode} ? "┘" : "-"), #  6 = 2 + 4 => connects north and west
                   $arg{twallcharnorth}                       || $arg{wallchar} || ($arg{unicode} ? "┴" : "-"), #  7 = 1 + 2 + 4 => connects east, north, and west.
                   $arg{vwallcharnorthend} || $arg{vwallchar} || $arg{wallchar} || ($arg{unicode} ? "│" : "|"), #  8 => connects south
                   $arg{nwcorner}                             || $arg{wallchar} || ($arg{unicode} ? "┌" : "-"), #  9 = 1 + 8 => connects east and south
                   $arg{vwallchar}                            || $arg{wallchar} || ($arg{unicode} ? "│" : "|"), # 10 = 2 + 8 => connects north and south
                   $arg{twallcharwest}                        || $arg{wallchar} || ($arg{unicode} ? "├" : "|"), # 11 = 1 + 2 + 8 => connects east, north, and south
                   $arg{necorner}                             || $arg{wallchar} || ($arg{unicode} ? "┐" : "-"), # 12 = 4 + 8 => connects west and south
                   $arg{twallcharsouth}                       || $arg{wallchar} || ($arg{unicode} ? "┬" : "-"), # 13 = 1 + 4 + 8 => connects east, west, and south
                   $arg{twallchareast}                        || $arg{wallchar} || ($arg{unicode} ? "┤" : "|"), # 14 = 2 + 4 + 8 => connects north, west, and south
                   $arg{crosswallchar}                        || $arg{wallchar} || ($arg{unicode} ? "┼" : "-"), # 15 = 1 + 2 + 4 + 8 => connects all four directions.
                  );
  my %walkable = map { $_ => "true" } qw(FLOOR CORR SCORR DOOR SDOOR SHALLOW STAIR);
  my %solid    = map { $_ => "true" } qw(STONE WALL);
  # First, check for doors that aren't accessible enough:
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if ($$map[$x][$y]{type} =~ /DOOR|SDOOR/) {
        my $floorct = countadjacent($map, $x, $y, $xmax, $ymax, qr/FLOOR|SHALLOW|LAKE|TRAP|STAIR/);
        if ($floorct < 1) {
          # Doors from one corridor to another should _usually_ be converted to secret corridor.
          if (90 > rand 100) {
            $$map[$x][$y] = terrain("SCORR");
          }
        }
        if (($x > 1) and ($y > 1) and ($x < $xmax) and ($y < $ymax) and
            (# Either it's a vertical door:
             ($$map[$x - 1][$y]{type} =~ /FLOOR|CORR|SHALLOW|LAKE|TRAP/ and
              $$map[$x + 1][$y]{type} =~ /FLOOR|CORR|SHALLOW|LAKE|TRAP/ and
              $$map[$x][$y - 1]{type} =~ /WALL|STONE/ and
              $$map[$x][$y + 1]{type} =~ /WALL|STONE/) or
             # Else it's a horizontal door
             ($$map[$x - 1][$y]{type} =~ /WALL|STONE/ and
              $$map[$x + 1][$y]{type} =~ /WALL|STONE/ and
              $$map[$x][$y - 1]{type} =~ /FLOOR|CORR|SHALLOW|LAKE|TRAP/ and
              $$map[$x][$y + 1]{type} =~ /FLOOR|CORR|SHALLOW|LAKE|TRAP/))) {
          # This door is okey dokey
        } else {
          if ($$map[$x][$y]{type} eq "SDOOR") {
            # Failed secret door, plaster it over:
            $$map[$x][$y] = terrain("WALL", bg => (($arg{debug} =~ /door/) ? "on_blue" : "on_black"));
          } else {
            # Failed regular door, just open it up:
            for my $dx (-1 .. 1) {
              for my $dy (-1 .. 1) {
                if (($x + $dx > 1) and ($x + $dx < $xmax) and
                    ($y + $dy > 1) and ($y + $dy < $ymax) and
                    (not $$map[$x][$y]{type} =~ /FLOOR|CORR|SHALLOW|LAKE|TRAP/) and
                    ((not $dx) or (not $dy) or (50 > rand 100))) {
                  $$map[$x + $dx][$y + $dy] = terrain("FLOOR");
                }}}
          }
        }
      } elsif ($$map[$x][$y]{type} =~ /CORR/) {
        # While we're at it, clean up any corridors that ended up in rooms:
        my $floorct = countadjacent($map, $x, $y, $xmax, $ymax, qr/FLOOR|SHALLOW|LAKE|TRAP|STAIR/);
        my $corrct  = countadjacent($map, $x, $y, $xmax, $ymax, qr/CORR/);
        if (($floorct > 3) or (($floorct > 1) and not $corrct)) {
          $$map[$x][$y] = terrain("FLOOR");
        }
      }
    }
  }
  if ($arg{checkstone}) {
    for my $x (1 .. $xmax) {
      for my $y (1 .. $ymax) {
        # Check for stone adjacent to floor, make it wall:
        if ($$map[$x][$y]{type} =~ /STONE/) {
          if (countadjacent($map, $x, $y, $xmax, $ymax, qr/FLOOR|SHALLOW|LAKE|TRAP|STAIR/)) {
            $$map[$x][$y] = terrain("WALL");
          }
        }
        # Also check for wall surrounded by wall/stone, and make it stone:
        if ($$map[$x][$y]{type} eq "WALL") {
          if (countadjacent($map, $x, $y, $xmax, $ymax, qr/WALL|STONE/) == 8) {
            $$map[$x][$y] = terrain("STONE");
          }
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
  my @wmap = map { [map { 0 } 0 .. $ymax ] } 0 .. $xmax;
  for my $x (2 .. ($xmax - 1)) {
    for my $y (2 .. ($ymax - 1)) {
      if ($$map[$x][$y]{type} =~ /FLOOR|SHALLOW|LAKE|TRAP|LAVA|STAIR/) {
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
  for my $x (1 .. $xmax) {
    for my $y (1 .. $ymax) {
      if (($x < $xmax) and not ($$map[$x+1][$y]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{EAST};
      }
      if (($x > 1) and not ($$map[$x-1][$y]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{WEST};
      }
      if (($y < $ymax) and not ($$map[$x][$y+1]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{SOUTH};
      }
      if (($y > 1) and not ($$map[$x][$y-1]{type} =~ /WALL|DOOR/)) {
        $wmap[$x][$y] &= ~ $dirbit{NORTH};
      }
      if ($$map[$x][$y]{type} eq 'WALL') {
        $$map[$x][$y]{char} = $wallglyph[$wmap[$x][$y]];
      }
    }
  }
  return $map;
}

sub countadjacent {
  my ($map, $x, $y, $xmax, $ymax, $typere) = @_;
  my $count = 0;
  for my $cx (($x - 1) .. ($x + 1)) {
    for my $cy (($y - 1) .. ($y + 1)) {
      if (($x == $cx) and ($y == $cy)) {
        # The tile itself does not count.
      } elsif (($cx < 1) or ($cx >= $xmax) or
               ($cy < 1) or ($cy >= $ymax)) {
        # Out of bounds, doesn't count
      } elsif ($$map[$cx][$cy]{type} =~ $typere) {
        $count++;
      }
    }
  }
  return $count;
}

42;
