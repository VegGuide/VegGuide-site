package VegGuide::Keywords;

use strict;
use warnings;

use VegGuide::UniqueArray;
use VegGuide::Validate qw( validate_pos SCALAR_TYPE );

{

    sub new {
        my $class = shift;

        return bless { array => VegGuide::UniqueArray->new() }, $class;
    }
}

{
    my @spec = (SCALAR_TYPE);

    sub add {
        my $self = shift;
        my ($word) = validate_pos( @_, @spec );

        $self->{array}->push($word);
    }
}

sub all {
    return $_[0]->{array}->values();
}

1;
