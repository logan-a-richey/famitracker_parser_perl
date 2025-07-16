#!/usr/bin/perl
use strict;
use warnings;

use JSON;

use lib 'FamiData';
use Project;
use Macro;
use Track;

my $input_file = $ARGV[0];
die "[Usage] $0 <input_file>\n" unless defined $input_file;

my $project = Project->new();
my $pattern_idx = 0;
my $track_idx = 0;

################################################################################
# Handlers

sub handle_info {
    my ($line) = @_;
    if ($line =~ /^\s*(TITLE|AUTHOR|COPYRIGHT)\s*\"(.*)\"/) {
        $project->{info}{lc $1} = $2;
    }
    elsif ($line =~ /^\s*COMMENT\s*\"(.*)\"/) {
        push @{$project->{info}{comment}}, $1;
    }
}

sub handle_setting {
    my ($line) = @_;
    if ($line =~ /^\s*(MACHINE|FRAMERATE|EXPANSION|VIBRATO|SPLIT|N163CHANNELS)\s+(\d+)/) {
        $project->{settings}{lc $1} = int($2);
    }
}

sub handle_macro {
    my ($line) = @_;
    if ($line =~ /^\s*(MACRO\w*)\s+(\d+)\s+(\d+)\s+(-?\d+)\s+(-?\d+)\s+(\d+)\s*:\s*(.*)/) {
        my ($tag, $type, $index, $loop, $release, $setting, $macros) = ($1, $2, $3, $4, $5, $6, $7);
        my @macro_values = split /\s+/, $macros;
        my $macro_obj = Macro->new(
            tag     => $tag,
            type    => $type,
            index   => $index,
            loop    => $loop,
            release => $release,
            setting => $setting,
            macro   => \@macro_values,
        );
        my $key = join("::", $tag, $type, $index);
        $project->{macro}{$key} = $macro_obj;
    }
}

sub handle_track {
    my ($line) = @_;
    if ($line =~ /^\s*TRACK\s+(\d+)\s+(\d+)\s+(\d+)\s*\"(.*)\"/) {
        $track_idx++;
        my ($num_rows, $speed, $tempo, $name) = ($1, $2, $3, $4);
        my $track = Track->new(
            name     => $name,
            speed    => $speed,
            tempo    => $tempo,
            num_rows => $num_rows,
        );
        $project->{tracks}{$track_idx} = $track;
    }
}

sub handle_columns {
    my ($line) = @_;
    if ($line =~ /^\s*COLUMNS\s*\:\s*(.*)/) {
        my @eff_cols = split /\s+/, $1;
        map {int($_)} @eff_cols;
        $project->{tracks}{$track_idx}{eff_cols} = \@eff_cols;
        $project->{tracks}{$track_idx}{num_cols} = $#eff_cols;
    }
}

sub handle_order {
    my ($line) = @_;
    if ($line =~ /^\s*ORDER\s+([0-9A-F]{2})\s*:\s*(.*)/) {
        my ($frame, $order_str) = ($1, $2);
        my @list = $order_str =~ /[0-9A-F]{2}/g;
        map {hex($_)} @list;
        $project->{tracks}{$track_idx}{orders}{$frame} = \@list;
    }
}

sub handle_pattern {
    my ($line) = @_;
    if ($line =~ /^\s*PATTERN\s+([0-9A-F]{2})/) {
        $pattern_idx = hex($1);
    }
}

sub handle_row {
    my ($line) = @_;
    if ($line =~ /^\s*ROW\s+([0-9A-F]{2})\s*:\s*(.*)/) {
        my ($i, $row_data) = (hex($1), $2);
        my @tokens = split /\:/, $row_data;
        for my $j (0 .. $#tokens) {
            my $token = $tokens[$j];
            $token =~ s/^\s+|\s+$//g;
            next if ($token =~ /^[\s\.]*$/);
            my $token_key = join('::', ("PAT=".$pattern_idx, "ROW=".$i, "COL = ".$j));
            $project->{tracks}{$track_idx}{tokens}{$token_key} = $token;
        }
    }
}

################################################################################
# Handler Table

my @handlers = (
    [qr/^(TITLE|AUTHOR|COPYRIGHT|COMMENT)/ => \&handle_info],
    [qr/^(MACHINE|FRAMERATE|EXPANSION|VIBRATO|SPLIT|N163CHANNELS)/ => \&handle_setting],
    [qr/^(MACRO|MACROVRC6|MACRON163|MACROS5B)/ => \&handle_macro],
    [qr/^TRACK/ => \&handle_track],
    [qr/^COLUMNS/ => \&handle_columns],
    [qr/^ORDER/ => \&handle_order],
    [qr/^PATTERN/ => \&handle_pattern],
    [qr/^ROW/ => \&handle_row],
);

################################################################################
# Main loop

open my $fh, '<', $input_file or die "Could not open $input_file: $!";
while (<$fh>) {
    chomp;
    next if /^\s*#/ || /^\s*$/;
    
    for my $h (@handlers) {
        if ($_ =~ $h->[0]) {
            $h->[1]->($_);
            last;
        }
    }
}
close $fh;
$project->show();

open my $out, '>', 'output.json' or die "Couldn't write JSON: $!";
print $out $project->get_json();
close $out;
print "Exported to output.json\n";

