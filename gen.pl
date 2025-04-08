#!/usr/bin/perl
use strict;
use warnings;
use List::Util qw(min max);
use File::Path qw(make_path);
use Digest::MD5 qw(md5_hex);
use Storable qw(dclone);

die "Usage: $0 level.txt\n" unless @ARGV == 1;

my $level_file = $ARGV[0];
open my $lfh, '<', $level_file or die "Can't open $level_file: $!";
my @map_raw = <$lfh>;
chomp @map_raw;
close $lfh;

my $height = scalar @map_raw;
my $width = length($map_raw[0]);
my @map;
my ($player_x, $player_y);
my @boxes;
my @goals;

# Parse map
for my $y (0..$#map_raw) {
    my @row = split //, $map_raw[$y];
    for my $x (0..$#row) {
        my $c = $row[$x];

        if ($c eq '#') {
            $map[$y][$x] = '#';
        } else {
            $map[$y][$x] = ' ';
        }

        if ($c eq '@') {
            ($player_x, $player_y) = ($x, $y);
        } elsif ($c eq '+') {
            ($player_x, $player_y) = ($x, $y);
            push @goals, [$x, $y];
        } elsif ($c eq '$') {
            push @boxes, [$x, $y];
        } elsif ($c eq '*') {
            push @boxes, [$x, $y];
            push @goals, [$x, $y];
        } elsif ($c eq '.') {
            push @goals, [$x, $y];
        }
    }
}

my %DIR = (
    w => [ 0, -1],  # up
    a => [-1,  0],  # left
    s => [ 0,  1],  # down
    d => [ 1,  0],  # right
);

my $output_dir = "game";
make_path($output_dir);

my %seen;
my %state_ids;
my @states;

my @queue = ({
    player => [$player_x, $player_y],
    boxes  => [ map { [@$_] } @boxes ],
});

while (my $state = shift @queue) {
    my $key = encode_state($state->{player}, $state->{boxes});
    next if $seen{$key}++;
    my $id = scalar @states;
    $state_ids{$key} = $id;
    push @states, $state;

    for my $dir (keys %DIR) {
        my $next = try_move($state, $dir);
        next unless $next;
        my $next_key = encode_state($next->{player}, $next->{boxes});
        push @queue, $next unless $seen{$next_key};
    }
}

for my $id (0 .. $#states) {
    generate_html($id, $states[$id]);
}

print "Generated ", scalar(@states), " pages\n";

# --- Helpers ---

sub encode_state {
    my ($player, $boxes) = @_;
    my @sorted = sort map { join(',', @$_) } @$boxes;
    return md5_hex(join(';', join(',', @$player), @sorted));
}

sub try_move {
    my ($state, $dir) = @_;
    my ($dx, $dy) = @{$DIR{$dir}};
    my ($px, $py) = @{$state->{player}};

    my $tx = $px + $dx;
    my $ty = $py + $dy;

    return if $map[$ty][$tx] eq '#';

    my %box_pos = map { join(',', @$_) => 1 } @{$state->{boxes}};

    if ($box_pos{"$tx,$ty"}) {
        my $nx = $tx + $dx;
        my $ny = $ty + $dy;
        return if $map[$ny][$nx] eq '#' || $box_pos{"$nx,$ny"};

        my @new_boxes = map {
            ($_->[0] == $tx && $_->[1] == $ty) ? [$nx, $ny] : [@$_]
        } @{$state->{boxes}};

        return {
            player => [$tx, $ty],
            boxes  => \@new_boxes,
        };
    }

    return {
        player => [$tx, $ty],
        boxes  => [ map { [@$_] } @{$state->{boxes}} ],
    };
}

sub generate_html {
    my ($id, $state) = @_;
    my $filename = sprintf("%s/state_%05d.html", $output_dir, $id);
    open my $fh, '>', $filename or die $!;

    my %box = map { join(',', @$_) => 1 } @{$state->{boxes}};
    my %goal = map { join(',', @$_) => 1 } @goals;
    my ($px, $py) = @{$state->{player}};

    # Check for solved state
    my $solved = 1;
    for my $b (@{$state->{boxes}}) {
        $solved = 0 unless $goal{join(',', @$b)};
    }

    print $fh <<'HTML';
<!DOCTYPE html><html><head><style>table{border-collapse:collapse}td{width:28px;height:28px;text-align:center;font-family:monospace;padding:0;margin:0;cursor:default}table a{text-decoration:none;display:flex;justify-content:center;align-items:center;height:100%;}table a:visited,table a:active,table a:link{color:black}.w{background:#000;color:#000}.g{background:#ffc}.b{background:orange}.p{background:#acf}.s{background:#cfc}</style></head><body>
HTML

    print $fh "<table>";
    for my $y (0 .. $#map) {
        print $fh "<tr>";
        for my $x (0 .. $#{$map[$y]}) {
            my $pos = "$x,$y";
            my ($class, $char) = ("", " ");
    
            if ($map[$y][$x] eq '#') {
                ($class, $char) = ("w", "#");
            } elsif ($px == $x && $py == $y) {
                ($class, $char) = ("p", '@');
            } elsif ($box{$pos} && $goal{$pos}) {
                ($class, $char) = ("s", '*');
            } elsif ($box{$pos}) {
                ($class, $char) = ("b", '$');
            } elsif ($goal{$pos}) {
                ($class, $char) = ("g", '.');
            }
    
            my $td = "<td";
            $td .= qq{ class="$class"} if $class;
            $td .= ">";
    
            # Determine direction if adjacent
            my $dx = $x - $px;
            my $dy = $y - $py;
            my $dir;
            $dir = 'd' if $dx == 1 && $dy == 0;
            $dir = 'a' if $dx == -1 && $dy == 0;
            $dir = 's' if $dx == 0 && $dy == 1;
            $dir = 'w' if $dx == 0 && $dy == -1;
    
            my $inner = $char;
    
            if ($dir) {
                my $next = try_move($state, $dir);
                if ($next) {
                    my $next_key = encode_state($next->{player}, $next->{boxes});
                    my $target_id = $state_ids{$next_key};
                    if (defined $target_id) {
                        my $href = sprintf("state_%05d.html", $target_id);
                        $inner = qq{<a href="$href">$inner</a>};
                    }
                }
            }
    
            $td .= "$inner</td>";
            print $fh $td;
        }
        print $fh "</tr>";
    }

    print $fh "</table>";

    # Movement links
    print $fh "<div>";
    for my $dir (qw(w a s d)) {
        my $next = try_move($state, $dir);
        my $target_id;
        if ($next) {
            my $next_key = encode_state($next->{player}, $next->{boxes});
            $target_id = $state_ids{$next_key};
        } else {
            $target_id = $id;
        }
        printf $fh qq{<a href="state_%05d.html" accesskey="%s">%s</a> },
            $target_id, $dir, uc($dir);
    }
    print $fh "</div>";

    # Final solved message
    print $fh qq{<div><small>Puzzle Solved!</small></div>} if $solved;

    print $fh "</body></html>";
    close $fh;
}

