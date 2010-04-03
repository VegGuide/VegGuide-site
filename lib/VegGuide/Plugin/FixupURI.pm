package VegGuide::Plugin::FixupURI;

use strict;
use warnings;

use MRO::Compat;

# A broken crawler keeps trying to fetch URIs like
# /location/data.rss%3flocation_id=196%26include_hours=0
# Unfortunately, for some reason I cannot match this with mod_rewrite
# (some escaping weirdness), so we have to handle it on the backend.
sub prepare_action {
    my $self = shift;

    if ( $self->request()->path() =~ m{^location.+\.rss$} ) {
        $self->response()->redirect( $self->request()->uri() );
    }

    return $self->maybe::next::method(@_);
}

sub dispatch {
    my $self = shift;

    return if $self->response()->redirect();

    return $self->maybe::next::method(@_);
}

1;
