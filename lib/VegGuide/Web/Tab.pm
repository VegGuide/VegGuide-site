package VegGuide::Web::Tab;

use strict;
use warnings;

use namespace::autoclean;
use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has uri => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has label => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has tooltip => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has id => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->label() },
);

has is_selected => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

__PACKAGE__->meta()->make_immutable();

1;
