package Project;
use strict;
use warnings;

use JSON;

sub new {
    my $class = shift;
    my $self = {
        info     => { title => undef, author => undef, copyright => undef, comment => [] },
        settings => { machine => 0, framerate => 0, expansion => 0, vibrato => 1, split => 32, n163channels => 0 },
        macro    => {},
        instrument => {},
        tracks   => {},
    };
    bless $self, $class;
    return $self;
}

sub show {
    my ($self) = @_;

    print "--- Song Info ---\n";
    for my $k (qw/title author copyright/) {
        print "$k => $self->{info}{$k}\n" if defined $self->{info}{$k};
    }

    print "\n--- Comments ---\n";
    print join("\n", @{$self->{info}{comment}}), "\n";

    print "\n--- Settings ---\n";
    for my $k (sort keys %{$self->{settings}}) {
        print "$k => $self->{settings}{$k}\n";
    }

    print "\n--- Macros ---\n";
    for my $k (sort keys %{$self->{macro}}) {
        my $m = $self->{macro}{$k};
        print "$k => ", join(", ", @{$m->{macro}}), "\n";
    }

    print "\n--- Tracks ---\n";
    for my $k (sort keys %{$self->{tracks}}) {
        print "$k => $self->{tracks}{$k}{name}\n";
    }
}

sub TO_JSON {
    my $self = shift;
    return {
        info     => $self->{info},
        settings => $self->{settings},
        macro    => $self->{macro},
        instrument => $self->{instrument},
        tracks   => $self->{tracks},
    };
}

sub get_json {
    my ($self) = @_;
    my $json = JSON->new->utf8->pretty->canonical->convert_blessed;
    return $json->encode($self);
}

1;
