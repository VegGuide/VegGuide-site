package VegGuide::Plugin::FixupHost;

use strict;
use warnings;

sub prepare_action
{
    my $self = shift;

    my $skin = $self->skin();
    my $host = $self->request()->uri()->host();

    if ( VegGuide::Config->IsProduction() )
    {
        my $skin_host = $self->skin()->hostname();
        my $uri_host  = $self->request()->uri()->host();

        if ( $uri_host && $uri_host !~ /^\Q$skin_host\./ )
        {
            $self->response()->redirect( 'http://' . $skin->hostname() . '.vegguide.org' );
        }
    }

    return $self->NEXT::prepare_action(@_);
}

sub dispatch
{
    my $self = shift;

    return if $self->response()->redirect();

    return $self->NEXT::dispatch(@_);
}


1;
