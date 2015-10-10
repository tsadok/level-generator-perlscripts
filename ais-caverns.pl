#!/usr/bin/perl

# We have an 80x21 space. Each square in it starts out as undecided,
# mark all the squares around the outside as wall, then we visit all
# the other squares in a random order, converting them to wall or to
# floor. A square is a floor if it has two walls 8-next to it, which
# don't have a continuous 4-path of wall squares between them; and a
# wall if there are any adjacent walls otherwise. The remaining case
# is no walls; in that case, we choose at random.

use warnings;
use strict;

use constant width => 80;
use constant height => 21;

use constant RIGHT => 1;
use constant UP => 2;
use constant LEFT => 4;
use constant DOWN => 8;
use constant CORRIDOR => 16;
use constant SOLID => 32;
use constant EDGE => 64;
use constant UNDECIDED => 128;

my @map;
my @coords;

my $depthfraction = $ARGV[0];

for my $x (0 .. (width-1)) {
    for my $y (0 .. (height-1)) {
        if ($x == 0 || $y == 0 || $x == width-1 || $y == height-1) {
            $map[$x][$y] = SOLID;
        } else {
            $map[$x][$y] = UNDECIDED;
            push @coords, [$x, $y];
        }
    }
}

# Shuffle the coordinates.
my @shuffled_coords;
while (@coords) {
    my $index = int(rand(@coords));
    push @shuffled_coords, splice @coords, $index, 1;
}

# Returns the neighbours of a square.
sub neighbours {
    my $x = shift;
    my $y = shift;
    return (
        $map[$x+1][$y], $map[$x+1][$y+1], $map[$x][$y+1], $map[$x-1][$y+1],
        $map[$x-1][$y], $map[$x-1][$y-1], $map[$x][$y-1], $map[$x+1][$y-1]);
}

# Places a wall on a square, with side effects:
# - Dead ends are recursively removed;
# - Squares that do not form part of a 2x2 square become corridor.
sub block_point {
    my $x = shift;
    my $y = shift;
    my $check = shift;
    my $mark_corridors = shift;
    $x == 0 || $y == 0 || $x == width-1 || $y == height-1 and return;
    $check and $map[$x][$y] & SOLID and return;
    my $wallcount =
        !!($map[$x+1][$y] & SOLID) + !!($map[$x][$y+1] & SOLID) +
        !!($map[$x-1][$y] & SOLID) + !!($map[$x][$y-1] & SOLID);
    if ($wallcount == 3 || !$check) {
        $map[$x][$y] &= ~(CORRIDOR | UNDECIDED);
        $map[$x][$y] |= SOLID;
        block_point($x+1, $y, 1, $mark_corridors);
        block_point($x, $y+1, 1, $mark_corridors);
        block_point($x-1, $y, 1, $mark_corridors);
        block_point($x, $y-1, 1, $mark_corridors);
        if ($mark_corridors) {
            block_point($x+1, $y+1, 1, $mark_corridors);
            block_point($x+1, $y-1, 1, $mark_corridors);
            block_point($x-1, $y+1, 1, $mark_corridors);
            block_point($x-1, $y-1, 1, $mark_corridors);
        }
    }
    if (!($map[$x][$y] & (SOLID | CORRIDOR)) && $mark_corridors) {
        my @neighbours = neighbours $x, $y;

        $map[$x][$y] |= CORRIDOR;
        $neighbours[$_] & SOLID or $neighbours[($_ + 1) % 8] & SOLID or
            $neighbours[($_ + 2) % 8] & SOLID or
            $map[$x][$y] &= ~CORRIDOR for (0,2,4,6);
    }
}

for my $cpair (@shuffled_coords) {
    my $x = $cpair->[0];
    my $y = $cpair->[1];

    $map[$x][$y] & UNDECIDED or next;

    my @neighbours = neighbours $x, $y;

    # To reduce diagonal chokepoints, we treat any diagonally adjacent floor
    # between two walls as a floor.
    $neighbours[$_] & SOLID and $neighbours[($_ + 2) % 8] & SOLID and
        $neighbours[$_ + 1] &= ~SOLID for (0, 2, 4, 6);

    my $transitioncount = 0;
    $transitioncount += (!($neighbours[$_] & SOLID) !=
                         !($neighbours[($_+1) % 8] & SOLID)) for 0..7;

    my $newval = $transitioncount > 2 ? 0 :
                 $transitioncount == 2 ? SOLID :
                 (rand) < ($depthfraction *
                           $depthfraction *
                           $depthfraction) ? SOLID : 0;

    # In order to get larger blocks of walls, if we just created a dead end,
    # we mark that cell as # even if it was previously ., because we know
    # that doing that cannot block connectivity.
    $map[$x][$y] = $newval;
    $newval & SOLID and block_point $x, $y, 0, 0;
}

# Now remove orphaned walls from the map.
for my $x (1 .. (width-2)) {
    for my $y (1 .. (height-2)) {
        $map[$x+1][$y] & SOLID or $map[$x-1][$y] & SOLID or
            $map[$x][$y+1] & SOLID or $map[$x][$y-1] & SOLID or
            $map[$x][$y] &= ~SOLID;
    }
}

# Mark corridors on the map.
for my $x (1 .. (width-2)) {
    for my $y (1 .. (height-2)) {
        block_point $x, $y, 1, 1;
    }
}

# To produce longer corridors, we block any squares that are diagonally
# adjacent to a corridor, but not orthogonally adjacent to a corridor or
# which have both squares a knight's move from the corridor open.
my $anychanges = 1;
while ($anychanges) {
    $anychanges = 0;
    LENGTHEN: for my $cpair (@shuffled_coords) {
        my $x = $cpair->[0];
        my $y = $cpair->[1];
        my @neighbours = neighbours $x, $y;
        $map[$x][$y] & (SOLID | CORRIDOR) and next;
        $neighbours[$_] & CORRIDOR and next LENGTHEN for (0, 2, 4, 6);
        $neighbours[$_] & CORRIDOR and 
            ($neighbours[($_ + 3) % 8] & (SOLID | CORRIDOR) ||
             $neighbours[($_ + 5) % 8] & (SOLID | CORRIDOR)) and
            ($anychanges = 1),
            block_point $x, $y, 0, 1 for (1, 3, 5, 7);
    }
}

# If a corridor has a length of exactly 2, convert it back to room squares.
# This looks neater than the alternative.
for my $x (1 .. (width-2)) {
    for my $y (1 .. (height-2)) {
        next unless $map[$x][$y] & CORRIDOR;
        for my $d ([0,+1],[0,-1],[+1,0],[-1,0]) {
            my ($d1, $d2) = @$d;
            next if
                $x == (width-2) && $d1 == 1 ||
                $y == (height-2) && $d2 == 1 ||
                $x == 1 && $d1 == -1 ||
                $y == 1 && $d2 == -1;
            next unless $map[$x+$d1][$y+$d2] & CORRIDOR;
            next if
                $map[$x+2*$d1][$y+2*$d2] & CORRIDOR ||
                $map[$x+$d1+$d2][$y+$d1+$d2] & CORRIDOR ||
                $map[$x+$d1-$d2][$y-$d1+$d2] & CORRIDOR ||
                $map[$x+$d2][$y+$d1] & CORRIDOR ||
                $map[$x-$d2][$y-$d1] & CORRIDOR ||
                $map[$x-$d1][$y-$d2] & CORRIDOR;
            $map[$x][$y] &= ~CORRIDOR;
            $map[$x+$d1][$y+$d2] &= ~CORRIDOR;
        }
    }
}

# Work out where walls should be. We start by drawing a square around every
# open floor space, then remove the parts of the square that do not connect
# to other walls.

my @walls = qw/! ─ │ └ ─ ─ ┘ ┴ │ ┌ │ ├ ┐ ┬ ┤ ┼
               ! ═ ║ ╚ ═ ═ ╝ ╩ ║ ╔ ║ ╠ ╗ ╦ ╣ ╬/;
$walls[0] = ' ';
for my $x (1 .. (width-2)) {
    for my $y (1 .. (height-2)) {
        next if $map[$x][$y] & (SOLID | CORRIDOR);

        $map[$x+1][$y] |= UP | DOWN;
        $map[$x-1][$y] |= UP | DOWN;
        $map[$x][$y+1] |= LEFT | RIGHT;
        $map[$x][$y-1] |= LEFT | RIGHT;
        $map[$x+1][$y+1] |= UP | LEFT;
        $map[$x-1][$y+1] |= UP | RIGHT;
        $map[$x+1][$y-1] |= DOWN | LEFT;
        $map[$x-1][$y-1] |= DOWN | RIGHT;
    }
}
for my $x (0 .. (width-1)) {
    for my $y (0 .. (height-1)) {
        $map[$x+1][$y] & (SOLID | CORRIDOR) or $map[$x][$y] &= ~RIGHT
            if $x < width-1;
        $map[$x-1][$y] & (SOLID | CORRIDOR) or $map[$x][$y] &= ~LEFT
            if $x > 0;
        $map[$x][$y+1] & (SOLID | CORRIDOR) or $map[$x][$y] &= ~DOWN
            if $y < height-1;
        $map[$x][$y-1] & (SOLID | CORRIDOR) or $map[$x][$y] &= ~UP
            if $y > 0;
    }
}

# Convert corridors on walls to secret doors if it doesn't create an obvious
# dead end (it usually does). The exception is dug-out corner squares, which
# are converted to diagonal chokepoints instead.
for my $cpair (@shuffled_coords) {
    my $x = $cpair->[0];
    my $y = $cpair->[1];
    next unless $map[$x][$y] & CORRIDOR;

    my @neighbours = neighbours $x, $y;

    CHECK_LONELY_CORRIDOR: {
        $neighbours[$_] & CORRIDOR and last CHECK_LONELY_CORRIDOR
            for (0, 2, 4, 6);

        $map[$x][$y] |= SOLID;
        $map[$x][$y] & (UP | DOWN) and $map[$x][$y] & (LEFT | RIGHT)
            and $map[$x][$y] &= ~CORRIDOR;
    }

    my $corridorcount = 0;
    $neighbours[$_] & CORRIDOR and !($neighbours[$_] & SOLID)
        and $corridorcount++ for (0, 2, 4, 6);

    next unless $corridorcount >= 3;

    ($map[$x+1][$y] & (CORRIDOR | 15)) == (CORRIDOR | UP | DOWN)
        and $map[$x+1][$y+1] & SOLID and $map[$x+1][$y-1] & SOLID
        and $map[$x+1][$y] |= SOLID, next;
    ($map[$x-1][$y] & (CORRIDOR | 15)) == (CORRIDOR | UP | DOWN)
        and $map[$x-1][$y+1] & SOLID and $map[$x-1][$y-1] & SOLID
        and $map[$x-1][$y] |= SOLID, next;
    ($map[$x][$y+1] & (CORRIDOR | 15)) == (CORRIDOR | LEFT | RIGHT)
        and $map[$x+1][$y+1] & SOLID and $map[$x-1][$y+1] & SOLID
        and $map[$x][$y+1] |= SOLID, next;
    ($map[$x][$y-1] & (CORRIDOR | 15)) == (CORRIDOR | LEFT | RIGHT)
        and $map[$x+1][$y-1] & SOLID and $map[$x-1][$y-1] & SOLID
        and $map[$x][$y-1] |= SOLID, next;
}

# Also make the entire corridor secret if it doesn't branch and ends cleanly
# at each end.
sub cleanly_ending_corridor {
    my ($x, $y) = @_;
    return unless $map[$x][$y] & CORRIDOR;

    my @neighbours = neighbours $x, $y;    
    my $corridorcount = 0;
    $neighbours[$_] & CORRIDOR and $corridorcount++ for (0, 2, 4, 6);
    return if $corridorcount != 1;
    return if $map[$x][$y] & LEFT && $map[$x-1][$y] & CORRIDOR;
    return if $map[$x][$y] & RIGHT && $map[$x+1][$y] & CORRIDOR;
    return if $map[$x][$y] & UP && $map[$x][$y-1] & CORRIDOR;
    return if $map[$x][$y] & DOWN && $map[$x][$y+1] & CORRIDOR;
    return 1;
}
sub mark_corridor_secret {
    my ($x, $y, $ox, $oy) = @_;
    $map[$x][$y] & CORRIDOR or return 0;
    $map[$x][$y] & SOLID and return 0;
    my @neighbours = neighbours $x, $y;    
    my $opencount = 0;
    $neighbours[$_] & SOLID or $opencount++ for (0, 2, 4, 6);
    $opencount > 2 and return 0;
    if ($ox != -1 && cleanly_ending_corridor $x, $y) {
        $map[$x][$y] |= SOLID;
        return 1;
    }
    my $a = 0;
    $a += mark_corridor_secret($x+1, $y, $x, $y)
        unless $ox == $x+1 && $oy == $y or $a;
    $a += mark_corridor_secret($x-1, $y, $x, $y)
        unless $ox == $x-1 && $oy == $y or $a;
    $a += mark_corridor_secret($x, $y+1, $x, $y)
        unless $ox == $x && $oy == $y+1 or $a;
    $a += mark_corridor_secret($x, $y-1, $x, $y)
        unless $ox == $x && $oy == $y-1 or $a;
    return $a;
}
for my $x (0 .. (width-1)) {
    for my $y (0 .. (height-1)) {
        next unless cleanly_ending_corridor $x, $y;
        if (mark_corridor_secret $x, $y, -1, -1) {
            $map[$x][$y] |= SOLID;
        }
    }
}

for my $y (0 .. (height-1)) {
    for my $x (0 .. (width-1)) {
        print
            $map[$x][$y] & SOLID ? $walls[$map[$x][$y] & 31] :
            $map[$x][$y] & CORRIDOR ? '#' : '.';
    }
    print "\n";
}
