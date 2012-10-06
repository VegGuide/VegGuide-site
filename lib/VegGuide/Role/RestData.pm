package VegGuide::Role::RestData;

use strict;
use warnings;

use Class::Trait 'base';

our @REQUIRES = '_core_rest_data';

use VegGuide::Validate qw( validate BOOLEAN );

sub rest_data {
    my $self = shift;
    my %p    = validate(
        @_,
        {
            include_related         => { type => BOOLEAN, default => 1 },
            include_complete_record => { type => BOOLEAN, default => 1 },
        }
    );

    $self->{core_rest_data}
        ||= $self->_core_rest_data( $p{include_complete_record} );

    return unless keys %{ $self->{core_rest_data} };

    return {
        %{ $self->{core_rest_data} },
        (
              $p{include_related} && $self->can('_related_rest_data')
            ? $self->_related_rest_data()
            : ()
        )
    };
}

1;
