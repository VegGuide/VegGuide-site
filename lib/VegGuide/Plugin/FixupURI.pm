package VegGuide::Plugin::FixupURI;

use strict;
use warnings;

use MRO::Compat;
use VegGuide::SiteURI qw( site_uri );

sub prepare_action {
    my $self = shift;

    # A broken crawler was trying to fetch URIs like
    # /location/data.rss%3flocation_id=196%26include_hours=0 Unfortunately,
    # for some reason I cannot match this with mod_rewrite (some escaping
    # weirdness), so we have to handle it on the backend.
    if ( $self->request->path =~ /{^location.+\.rss$/ ) {
        $self->response->redirect( $self->request->uri );
    }

    # There have been a number of requests for URIs like
    # http://www.vegguide.org/region/616/filter?sort_order=ASC%3Bpage%3D1%3Border_by%3Dname%3Blimit%3D20. I'm
    # not sure where they're coming from, but they're easy enough to rewrite
    # into something correct.
    my $p = $self->request->params;
    if ( $p->{sort_order} && $p->{sort_order} =~ /^(ASC|DESC);(.+)$/ ) {
        my %new_p = (
            sort_order => $1,
        );
        for my $pair ( split /;/, $2 ) {
            my ( $k, $v ) = split /=/, $pair, 2;
            $new_p{$k} = $v;
        }

        my $uri = site_uri(
            path      => $self->request->path,
            query     => \%new_p,
            with_host => 1,
        );
        $self->response->redirect($uri);
    }

    return $self->maybe::next::method(@_);
}

sub dispatch {
    my $self = shift;

    return if $self->response->redirect;

    return $self->maybe::next::method(@_);
}

1;
