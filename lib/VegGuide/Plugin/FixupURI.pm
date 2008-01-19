package VegGuide::Plugin::FixupURI;

use strict;
use warnings;

# A broken crawler keeps trying to fetch URIs like
# /location/data.rss%3flocation_id=196%26include_hours=0
# Unfortunately, Apache escapes the string _before_ mod_rewrite has a
# chance to see it, so we have to handle it on the backend.
sub prepare_action
{
    my $self = shift;

    my $path = $self->request()->path();

    if ( $path =~ /(.+\.rss)%3f(.+)$/ )
    {
        my $real_path = $1;
        my $query = $2;

        $query =~ s/%26/&/g;

        $self->response()->redirect( q{/} . $real_path . q{?} . $query );
    }

    return $self->NEXT::prepare_action(@_);
}

1;
