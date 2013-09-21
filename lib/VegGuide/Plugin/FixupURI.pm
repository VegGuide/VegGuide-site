package VegGuide::Plugin::FixupURI;

use strict;
use warnings;

use MRO::Compat;

# Some weird broken URIS:
#
# * A broken crawler keeps trying to fetch URIs like
#   /location/data.rss%3flocation_id=196%26include_hours=0 Unfortunately, for
#   some reason I cannot match this with mod_rewrite (some escaping
#   weirdness), so we have to handle it on the backend.
#
# * Some browsers keep requesting URIs like /user/login_form/-/index.php
sub prepare_action {
    my $self = shift;

    if ( $self->request()->path() =~ m{^location.+\.rss$} ) {
        $self->response()->redirect( $self->request()->uri() );
    }

    if ( $self->request()->path() =~ m{/.+/-/index\.php} ) {
        $uri = $self->request()->uri() =~ s{/-/.+$}{}r;
        $self->response()->redirect($uri);
    }

    return $self->maybe::next::method(@_);
}

sub dispatch {
    my $self = shift;

    return if $self->response()->redirect();

    return $self->maybe::next::method(@_);
}

1;
