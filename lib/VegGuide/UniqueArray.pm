package VegGuide::UniqueArray;

use strict;
use warnings;

use Tie::IxHash;

sub new {
    my $class = shift;

    return bless { hash => Tie::IxHash->new() }, $class;
}

sub push {
    my $self = shift;

    for my $v (@_) {
        return if $self->{hash}->EXISTS($v);

        $self->{hash}->Push( $v, 1 );
    }
}

sub values {
    return $_[0]->{hash}->Keys();
}

1;
