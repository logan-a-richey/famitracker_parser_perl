#!/usr/bin/perl

use strict;
use warnings;
use JSON;

# ==============================================================================
# Globals

our %project = (
    info       => {},
    settings   => {},
    macros     => {},
    instruments => {},
    tracks     => {}
);
our $track_idx   = 0;
our $pattern_idx = 0;

# ==============================================================================
# Helper Functions

sub get_macro_key {
    my ($tag, $type, $index) = @_;
    return join("::", "TAG=$tag", "TYPE=$type", "INDEX=$index");
}

sub get_token_key {
    my ($pat, $row, $col) = @_;
    return join("::", "PAT=$pat", "ROW=$row", "COL=$col");
}

# ==============================================================================
# Handlers

sub handle_info {
    # TITLE [title]
    my $line = shift;
    if ($line =~ /^\s*(TITLE|AUTHOR|COPYRIGHT)\s*\"(.*)\"/) {
        $project{info}{lc $1} = $2;
    } 
    elsif ($line =~ /^\s*COMMENT\s*\"(.*)\"/) {
        if (not defined $project{info}{comment}) {
            $project{info}{comment} = [];
        }
        push @{$project{info}{comment}}, $1;
    }
}

sub handle_settings {
    # MACHINE [machine]
    my $line = shift;
    unless ($line =~ /^\s*(MACHINE|FRAMERATE|EXPANSION|VIBRATO|SPLIT|N163CHANNELS)\s+(\d+)/) { return; }
    $project{settings}{lc $1} = int($2);
}

sub handle_macro {
    # MACRO [type] [index] [loop] [release] [setting] : [macro]
    my $line = shift;
    my @matches;
    unless (@matches = ($line =~ /^\s*
        (MACRO\w*)\s+
        (\d+)\s+(\d+)\s+(\-?\d+)\s+(\-?\d+)\s+(\d+)
        \s*\:\s*
        (.*)/x)) { return; }
    my ($tag, $type, $index, $loop, $release, $setting, $data) = @matches;
    my @sequence = split /\s+/, $data;

    my $macro_key = get_macro_key($tag, $type, $index);
    $project{macros}{$macro_key} = {
        tag      => $tag,
        type     => $type,
        index    => $index,
        loop     => $loop,
        release  => $release,
        setting  => $setting,
        sequence => \@sequence,
    };
}

sub handle_inst_basic {
    # INST2A03 [index] [seq_vol] [seq_arp] [seq_pit] [seq_hpi] [seq_dut] [name]
    my $line = shift;
    my @matches;
    unless (@matches = ($line =~ /^\s*
        (INST20A3|INSTVRC6|INSTS5B)\s+
        (\d+)\s+
        (\-?\d+)\s+(\-?\d+)\s+(\-?\d+)\s+(\-?\d+)\s+(\-?\d+)\s*
        \"(.*)\"/x)) { return; }
    my ($tag, $index, $seq_vol, $seq_arp, $seq_pit, $seq_hpi, $seq_dut, $name) = @matches;
    $project{instruments}{$index} = {
        tag  => $tag,
        name => $name
    };
    
    my ($VOL_TYPE, $ARP_TYPE, $PIT_TYPE, $HPI_TYPE, $DUT_TYPE) = (0 .. 4);
    my %macros = (
        macro_vol => [$VOL_TYPE, $seq_vol],
        macro_arp => [$ARP_TYPE, $seq_arp],
        macro_pit => [$PIT_TYPE, $seq_pit],
        macro_hpi => [$HPI_TYPE, $seq_hpi],
        macro_dut => [$DUT_TYPE, $seq_dut]
    );

    my $macro_tag = $tag; 
    $macro_tag =~ s/INST/MACRO/;

    for my $k (keys %macros) {
        my ($type, $seq) = @{$macros{$k}};
        my $macro_key = get_macro_key($macro_tag, $type, $seq);
        if (exists $project{macros}{$macro_key}) {
            $project{instruments}{$index}{$k} = $project{macros}{$macro_key};
        }
    }
}

sub handle_inst_vrc7 {
    # INSTVRC7 [index] [patch] [r0] [r1] [r2] [r3] [r4] [r5] [r6] [r7] [name]
    my $line = shift;
    my @matches;
    unless (@matches = ($line =~ /^\s*
        (INSTVRC7)\s+(\d+)\s+(\d+)\s+
        ([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})\s+
        ([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})\s*
        \"(.*)\"/x)) { return; }
    my ($tag, $index, $patch, $r0, $r1, $r2, $r3, $r4, $r5, $r6, $r7, $name) = @matches;
    $project{instruments}{$index} = {
        tag   => $tag,
        index => $index,
        patch => $patch,
        r0 => $r0, r1 => $r1, r2 => $r2, r3 => $r3,
        r4 => $r4, r5 => $r5, r6 => $r6, r7 => $r7,
        name  => $name
    };
}

sub handle_inst_fds {
    # INSTFDS [index] [mod_enable] [mod_speed] [mod_depth] [mod_delay] [name]
    my $line = shift;
    my @matches;
    unless (@matches = ($line =~ /^\s*
        (INSTFDS)\s+
        (\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*
        \"(.*)\"/x)) { return; }
    my ($tag, $index, $mod_enable, $mod_speed, $mod_depth, $mod_delay, $name) = @matches;

    $project{instruments}{$index} = {
        tag => $tag,
        index => $index,
        mod_enable => $mod_enable,
        mod_speed => $mod_speed,
        mod_depth => $mod_depth,
        mod_delay => $mod_delay,
        name => $name
    };
}

sub handle_inst_n163 {
    # INSTN163 [index] [seq_vol] [seq_arp] [seq_pit] [seq_hpi] [seq_wav] [w_size] [w_pos] [w_count] [name]
    my $line = shift;
    my @matches;
    unless (@matches = ($line =~ /^\s*
        (INSTN163)\s+ 
        (\d+)\s+    
        (\-?\d+)\s+(\-?\d+)\s+(\-?\d+)\s+(\-?\d+)\s+(\-?\d+)\s+
        (\d+)\s+(\d+)\s+(\d+)\s*
        \"(.*)\"    
    /x)) { return; }
    my ($tag, $index, $seq_vol, $seq_arp, $seq_pit, $seq_hpi, $seq_dut, $w_size, $w_pos, $w_count, $name) = @matches;
    $project{instruments}{$index} = {
        tag  => $tag,
        name => $name,
        w_size => $w_size,
        w_pos => $w_pos,
        w_count => $w_count,
    };

    my ($VOL_TYPE, $ARP_TYPE, $PIT_TYPE, $HPI_TYPE, $DUT_TYPE) = (0 .. 4);
    my %macros = (
        macro_vol => [$VOL_TYPE, $seq_vol],
        macro_arp => [$ARP_TYPE, $seq_arp],
        macro_pit => [$PIT_TYPE, $seq_pit],
        macro_hpi => [$HPI_TYPE, $seq_hpi],
        macro_dut => [$DUT_TYPE, $seq_dut]
    );

    my $macro_tag = $tag; 
    $macro_tag =~ s/INST/MACRO/;

    for my $k (keys %macros) {
        my ($type, $seq) = @{$macros{$k}};
        my $macro_key = get_macro_key($macro_tag, $type, $seq);
        if (exists $project{macros}{$macro_key}) {
            $project{instruments}{$index}{$k} = $project{macros}{$macro_key};
        }
    }
}

sub handle_instrument {
    my $line = shift;
    handle_inst_basic($line);
    handle_inst_vrc7($line);
    handle_inst_fds($line);
    handle_inst_n163($line);
}

sub handle_track {
    # TRACK [pattern] [speed] [tempo] [name]
    my $line = shift;
    my @matches; 
    unless (@matches = ($line =~ /^\s*TRACK\s+(\d+)\s+(\d+)\s+(\d+)\s*\"(.*)\"/)) { return; }
    $track_idx++;
    my ($num_rows, $speed, $tempo, $name) = @matches;
    $project{tracks}{$track_idx} = {
        name     => $name,
        speed    => $speed,
        tempo    => $tempo,
        num_rows => $num_rows,
        num_cols => 5,
        eff_cols => [1, 1, 1, 1, 1],
        orders   => {},
        tokens   => {}
    };
}

sub handle_columns {
    # COLUMNS : [columns]
    my $line = shift;
    unless ($line =~ /^\s*COLUMNS\s*\:\s*(.*)/) { return; }
    my @eff_cols = split /\s+/, $1;
    @eff_cols = map { int($_) } @eff_cols;
    $project{tracks}{$track_idx}{eff_cols} = \@eff_cols;
    $project{tracks}{$track_idx}{num_cols} = scalar @eff_cols;
}

sub handle_order {
    # ORDER [frame] : [list]
    my $line = shift;
    unless ($line =~ /^\s*ORDER\s+([0-9A-F]{2})\s*:\s*(.*)/) { return; }
    my ($frame, $order_str) = ($1, $2);
    my @list = $order_str =~ /[0-9A-F]{2}/g;
    @list = map { hex($_) } @list;
    $project{tracks}{$track_idx}{orders}{$frame} = \@list;
}

sub handle_pattern {
    # PATTERN [pattern]
    my $line = shift;
    unless ($line =~ /^\s*PATTERN\s+([0-9A-F]{2})/) { return; }
    $pattern_idx = hex($1);
}

sub handle_row {
    # ROW [row] : [c0] : [c1] : [c2] ...
    my $line = shift;
    unless ($line =~ /^\s*ROW\s+([0-9A-F]{2})\s*:\s*(.*)/) { return; }
    my ($i, $row_data) = (hex($1), $2);
    my @tokens = split /\:/, $row_data;
    for my $j (0 .. $#tokens) {
        my $token = $tokens[$j];
        $token =~ s/^\s+|\s+$//g;
        next if ($token =~ /^[\s\.]*$/);
        my $token_key = get_token_key($pattern_idx, $i, $j);
        $project{tracks}{$track_idx}{tokens}{$token_key} = $token;
    }
}

# ==============================================================================
# Handlers Table

my @dtable = (
    [qr/^(TITLE|AUTHOR|COPYRIGHT|COMMENT)/, \&handle_info],
    [qr/^(MACHINE|FRAMERATE|EXPANSION|VIBRATO|SPLIT|N163CHANNELS)/, \&handle_settings],
    [qr/^(MACRO|MACROVRC6|MACRON163|MACROS5B)/, \&handle_macro],
    [qr/^(INSTVRC6|INSTVRC7|INSTN163|INST2A03|INSTFDS|INSTS5B)/, \&handle_instrument],
    [qr/^TRACK/, \&handle_track],
    [qr/^COLUMNS/, \&handle_columns],
    [qr/^ORDER/, \&handle_order],
    [qr/^PATTERN/, \&handle_pattern],
    [qr/^ROW/, \&handle_row],
);

# ==============================================================================
# Main

sub read_file {
    # Get input from cmdline
    die "Usage: $0 <input file>\n" unless @ARGV >= 1;
    my $input = $ARGV[0];
    
    # Read file:
    open my $FH, '<', $input or die $!;

    my ($MATCHER, $HANDLER) = (0, 1);
    while (my $line = <$FH>) {
        chomp $line;
        # skip on comment line or blank line
        if ($line =~ /^\s*#/ || $line =~ /^\s*$/) { next; }

        for my $h (@dtable) {
            if ($line =~ $h->[$MATCHER]) {
                ($h->[$HANDLER])->($line);
                last;
            }
        }
    }
    close $FH;
}

sub write_file {
    # Write file:
    open my $OUT_FH, '>', 'output.json' or die "Couldn't write JSON: $!";
    my $json = JSON->new->utf8->pretty->canonical->convert_blessed;
    print $OUT_FH $json->encode(\%project);
    close $OUT_FH;
    print "Exported to output.json\n";
}

sub main {
    read_file();
    write_file();
}

main();
