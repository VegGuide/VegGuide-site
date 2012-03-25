package VegGuide::AlternateLinks;

use strict;
use warnings;

use Scalar::Util qw( weaken );
use VegGuide::AlternateLink;
use VegGuide::UniqueArray;
use VegGuide::Validate qw( validate_pos );

sub new {
    my $class = shift;

    return bless { array => VegGuide::UniqueArray->new() }, $class;
}

sub add {
    my $self = shift;

    $self->{array}->push( VegGuide::AlternateLink->new(@_) );
}

sub all {
    return $_[0]->{array}->values();
}

1;
