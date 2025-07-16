package Macro;
use strict;
use warnings;

use JSON;

sub new {
    my ($class, %args) = @_;
    my $self = {
        tag     => $args{tag}     // 'MACRO',
        type    => $args{type}    // 0,
        index   => $args{index}   // 0,
        loop    => $args{loop}    // -1,
        release => $args{release} // -1,
        setting => $args{setting} // 0,
        macro   => $args{macro}   // [],
    };
    bless $self, $class;
    return $self;
}

sub TO_JSON {
    my $self = shift;
    return {
        tag     => $self->{tag},
        type    => $self->{type},
        index   => $self->{index},
        loop    => $self->{loop},
        release => $self->{release},
        setting => $self->{setting},
        macro   => $self->{macro},
    };
}

1;
