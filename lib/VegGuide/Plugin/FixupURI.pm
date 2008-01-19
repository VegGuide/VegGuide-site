package VegGuide::Plugin::FixupURI;

use strict;
use warnings;

# A broken crawler keeps trying to fetch URIs like
# /location/data.rss%3flocation_id=196%26include_hours=0
# Unfortunately, Apache unescapes the string _before_ mod_rewrite has
# a chance to see it, so we have to handle it on the backend.
sub prepare_action
{
    my $self = shift;

    if ( $self->request()->path() =~ m{location/[^/]+.+\.rss} )
    {
        $self->response()->redirect( $self->request()->uri() );
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
