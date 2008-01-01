package VegGuide::Plugin::ErrorHandling;

use strict;
use warnings;

use HTTP::Status qw( RC_NOT_FOUND RC_INTERNAL_SERVER_ERROR );


sub finalize_error
{
    my $self    = shift;

    if ( $self->debug() )
    {
        $self->NEXT::finalize_error( $self, @_ );
        return;
    }

    my @errors = @{ $self->error() || [] };

    $self->log()->error($_) for @errors;

    my $status =
        ( grep { /unknown resource|no default/i } @errors ) ? RC_NOT_FOUND : RC_INTERNAL_SERVER_ERROR;

    $self->error( [] );

    $self->response()->content_type('text/html; charset=utf-8');
    $self->response()->status($status);
    $self->response()->body( $self->subreq( "/error/$status" ) );
}


1;
