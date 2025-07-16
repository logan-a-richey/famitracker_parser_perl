package Track;
use strict;
use warnings;

use JSON;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name     => $args{name}     // 'NewSong',
        speed    => $args{speed}    // 6,
        tempo    => $args{tempo}    // 150,
        num_rows => $args{num_rows} // 64,
        num_cols => $args{num_cols} // 5,
        eff_cols => $args{eff_cols} // [1, 1, 1, 1, 1],
        orders   => {},
        tokens   => {},
    };
    bless $self, $class;
    return $self;
}

sub TO_JSON {
    my $self = shift;
    return {
        name      => $self->{name},
        speed     => $self->{speed},
        tempo     => $self->{tempo},
        num_rows  => $self->{num_rows},
        num_cols  => $self->{num_cols},
        eff_cols  => $self->{eff_cols},
        orders    => $self->{orders},
        tokens    => $self->{tokens},
    };
}

1;
