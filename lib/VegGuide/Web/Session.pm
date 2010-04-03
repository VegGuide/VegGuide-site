package VegGuide::Web::Session;

use strict;
use warnings;

use VegGuide::Types qw( ArrayRef HashRef NonEmptyStr ErrorForSession );

use Moose;
use MooseX::Params::Validate qw( pos_validated_list );
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has form_data => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    default => sub { {} },
);

has _errors => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => ArrayRef [ NonEmptyStr | HashRef ],
    default  => sub { [] },
    init_arg => undef,
    handles  => {
        add_error => 'push',
        errors    => 'elements',
    },
);

has _messages => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => ArrayRef [NonEmptyStr],
    default  => sub { [] },
    init_arg => undef,
    handles  => {
        add_message => 'push',
        messages    => 'elements',
    },
);

around add_error => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig( map { $self->_error_text($_) } @_ );
};

sub _error_text {
    my $self = shift;
    my ($e) = pos_validated_list( \@_, { isa => ErrorForSession } );

    if ( eval { $e->can('messages') } && $e->messages() ) {
        return $e->messages();
    }
    elsif ( eval { $e->can('message') } ) {
        return $e->message();
    }
    elsif ( ref $e ) {
        return @{$e};
    }
    else {

        # force stringification
        return $e . q{};
    }
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
