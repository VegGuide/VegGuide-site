package VegGuide::Breadcrumbs;

use strict;
use warnings;

use Scalar::Util qw( weaken );
use VegGuide::SiteURI qw( region_uri );
use VegGuide::UniqueArray;
use VegGuide::Validate qw( validate_pos );

{
    my @spec = ( { can => 'request' } );

    sub new {
        my $class = shift;
        my ($request) = validate_pos( @_, @spec );

        my $self = bless { array => VegGuide::UniqueArray->new() }, $class;

        $self->{catalyst} = $request;
        weaken $self->{catalyst};

        return $self;
    }
}

sub add {
    my $self = shift;

    $self->{array}->push( VegGuide::Breadcrumb->new(@_) );
}

sub add_region_breadcrumbs {
    my $self     = shift;
    my $location = shift;

    for my $l ( $location->ancestors(), $location ) {
        $self->add(
            uri   => region_uri( location => $l ),
            label => $l->name(),
        );
    }
}

sub add_standard_breadcrumb {
    my $self = shift;

    $self->add(
        uri   => $self->{catalyst}->request()->uri()->as_string(),
        label => shift,
    );
}

sub all {
    return $_[0]->{array}->values();
}

package VegGuide::Breadcrumb;

use overload (
    '""'     => 'as_string',
    'eq'     => sub { $_[0]->as_string() eq $_[1]->as_string() },
    fallback => 1
);

use Scalar::Util qw( blessed );
use VegGuide::Validate qw( validate SCALAR_TYPE );

{
    my $spec = {
        uri => {
            callbacks => {
                'string or URI object' => sub {
                    return 1 if defined $_[0] && !ref $_[0] && length $_[0];
                    return 1 if blessed $_[0] && $_[0]->can('as_string');
                },
            },
        },
        label => SCALAR_TYPE,
    };

    sub new {
        my $class = shift;
        my %p = validate( @_, $spec );

        return bless \%p, $class;
    }
}

sub uri { $_[0]->{uri} }

sub label { $_[0]->{label} }

sub as_string {
    return join '|', $_[0]->uri(), $_[0]->label();
}

1;
