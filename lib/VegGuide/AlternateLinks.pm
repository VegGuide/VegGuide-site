package VegGuide::AlternateLinks;

use strict;
use warnings;

use Scalar::Util qw( weaken );
use VegGuide::UniqueArray;
use VegGuide::Validate qw( validate_pos );

sub new {
    my $class = shift;

    return bless { array => VegGuide::UniqueArray->new() }, $class;
}

{

    sub add {
        my $self = shift;

        $self->{array}->push( VegGuide::AlternateLink->new(@_) );
    }
}

sub all {
    return $_[0]->{array}->values();
}

package VegGuide::AlternateLink;

use overload (
    '""'     => 'as_string',
    'eq'     => sub { $_[0]->as_string() eq $_[1]->as_string() },
    fallback => 1
);

use VegGuide::Validate qw( validate SCALAR_TYPE );

{
    my $spec = {
        mime_type => SCALAR_TYPE,
        title     => SCALAR_TYPE,
        uri       => SCALAR_TYPE,
    };

    sub new {
        my $class = shift;
        my %p = validate( @_, $spec );

        return bless \%p, $class;
    }
}

sub mime_type { $_[0]->{mime_type} }

sub uri { $_[0]->{uri} }

sub title { $_[0]->{title} }

sub as_string { $_[0]->uri() }

1;
