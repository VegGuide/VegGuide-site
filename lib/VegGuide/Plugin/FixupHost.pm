package VegGuide::Plugin::FixupHost;

use strict;
use warnings;

use MRO::Compat;

sub prepare_action {
    my $self = shift;

    my $skin = $self->skin();
    my $host = $self->request()->uri()->host();

    if ( VegGuide::Config->IsProduction() ) {
        my $skin_host = $self->skin()->hostname();
        my $uri_host  = $self->request()->uri()->host();

        if ( $uri_host && $uri_host !~ /^\Q$skin_host./ ) {
            $self->response()
                ->redirect( 'http://' . $skin->hostname() . '.vegguide.org' );
        }
    }

    return $self->maybe::next::method(@_);
}

sub dispatch {
    my $self = shift;

    return if $self->response()->redirect();

    return $self->maybe::next::method(@_);
}

1;
