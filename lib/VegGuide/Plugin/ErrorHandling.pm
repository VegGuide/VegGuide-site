package VegGuide::Plugin::ErrorHandling;

use strict;
use warnings;

use HTTP::Status qw( RC_NOT_FOUND RC_INTERNAL_SERVER_ERROR );
use VegGuide::JSON;


# I'd really rather _not_ copy this whole thing in here, but it's the
# only way to override how errors are logged. I have to monkey-patch
# rather than subclassing or else NEXT::finalize() ends up calling the
# finalize in Catalyst itself before calling finalize() for other
# plugins (a mess!).
{
    package Catalyst;

    no warnings 'redefine';
sub finalize {
    my $self = shift;

    $self->NEXT::finalize(@_);

    for my $error ( @{ $self->error } ) {
        $self->_log_error($error);
    }

    # Allow engine to handle finalize flow (for POE)
    if ( $self->engine->can('finalize') ) {
        $self->engine->finalize($self);
    }
    else {

        $self->finalize_uploads;

        # Error
        if ( $#{ $self->error } >= 0 ) {
            $self->finalize_error;
        }

        $self->finalize_headers;

        # HEAD request
        if ( $self->request->method eq 'HEAD' ) {
            $self->response->body('');
        }

        $self->finalize_body;
    }
    
    if ($self->use_stats) {        
        my $elapsed = sprintf '%f', $self->stats->elapsed;
        my $av = $elapsed == 0 ? '??' : sprintf '%.3f', 1 / $elapsed;
        $self->log->info(
            "Request took ${elapsed}s ($av/s)\n" . $self->stats->report . "\n" );        
    }

    return $self->response->status;
}
}
sub _log_error
{
    my $self  = shift;
    my $error = shift;

    # XXX - change this later to log to the apache log?
#    if ( $error =~ /unknown resource/ )

    my %error = ( uri => $self->request()->uri() . '' );

    if ( my $user = $self->vg_user() )
    {
        $error{user} = $user->real_name();
        $error{user} .= q{ - } . $user->user_id()
            if $user->user_id();
    }

    if ( my $ref = $self->request()->referer() )
    {
        $error{referer} = $ref;
    }

    $error{error} = $error . '';

    $self->log()->error( VegGuide::JSON->Encode( \%error ) );
}

sub finalize_error
{
    my $self = shift;

    if ( $self->debug() )
    {
        $self->NEXT::finalize_error( $self, @_ );
        return;
    }

    my @errors = @{ $self->error() || [] };

    my $status =
        ( grep { /unknown resource|no default/i } @errors ) ? RC_NOT_FOUND : RC_INTERNAL_SERVER_ERROR;

    $self->error( [] );

    $self->response()->content_type('text/html; charset=utf-8');
    $self->response()->status($status);
    $self->response()->body( $self->subreq( "/error/$status" ) );
}


1;
