#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use JSON;
$Data::Dumper::Indent = 1; 

my $data = {};
my $header = "";

my $input = $ARGV[0] || "";
if (not defined $input) {
    die "Usage: $0 input.txt\n";
}

open(my $fh, '<', $input) or die "Could not open file: $!\n";

# <=>

# my $line_no = 0;
while (my $line = <$fh>) 
{
    chomp $line;    
    # $line_no++;
    
    # skip comment lines and blank lines
    if ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
        next;
    }
    
    # field update
    if ($line =~ /^\s*\-\s*(\w+)\:\s*(\w+)/) 
    {
        unless ($header) 
        {
            warn "Header undefined";
            next;
        }
        my ($field, $type) = ($1, $2);
        $data->{$header}{$field}{"type"} = $type;
        
        # range check 
        if ($line =~ /^\s*\-\s*\w+\:\s*\w+\[(\-?[0-9A-Fa-f]+)\s*\,\s*(\-?[0-9A-Fa-f]+)\]/)
        {
            my ($lower, $upper) = ($1, $2);
            if ($type =~ /hex/) {
                $lower = hex($lower);
                $upper = hex($upper);
            }
            $data->{$header}{$field}{"range"}{"lower"} = $lower;
            $data->{$header}{$field}{"range"}{"upper"} = $upper;
        }
        
        # info check
        if ($line =~ /^.*\-.*\-\s*(.*)/) {
            my $info = $1;
            $data->{$header}{$field}{"info"} = $info || "";
        }
    }

    # header update
    if ($line =~ /^\s*(\w+)/) {
        $header = lc($1);
    }
}

# print(Dumper($data), "\n");
open my $OUT, '>', 'export_spec.json' or die "Couldn't write export_spec.json: $!\n";
my $json = JSON->new->utf8->pretty->canonical;
print $OUT $json->encode($data);
close $OUT;
print "Exported to export_spec.json\n";

