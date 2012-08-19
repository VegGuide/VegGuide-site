package VegGuide::Controller::Search;

use strict;
use warnings;
use namespace::autoclean;

use URI::Escape qw( uri_escape );
use VegGuide::Geocoder;
use VegGuide::Search::Vendor::ByLatLong;
use VegGuide::Search::Vendor::ByName;
use VegGuide::SiteURI qw( static_uri );

use Moose;

BEGIN { extends 'VegGuide::Controller::Base'; }

with 'VegGuide::Role::Controller::Search';

{
    my %SearchConfig = (
        captured_path_position => 2,
        search_class           => 'VegGuide::Search::Vendor::ByLatLong',
        extra_params           => sub {
            my $caps = $_[0]->request()->captures();
            return (
                latitude  => $caps->[0],
                longitude => $caps->[1],
                address   => 'your location',
            );
        },
    );

    sub by_lat_long :
        LocalRegex('^by-lat-long/(-?[\d\.]+),(-?[\d\.]+)(?:/filter(?:/(.*)))?$')
        : ActionClass('+VegGuide::Action::REST') { }

    sub by_lat_long_GET : Private {
        my $self = shift;
        my $c    = shift;

        $self->_set_search_in_stash( $c, %SearchConfig );

        $self->_set_cursor_params($c);

        my $search = $c->stash()->{search};

        my $path
            = '/search/by-lat-long/'
            . uri_escape( $search->latitude() ) . ','
            . uri_escape( $search->longitude() );

        $self->_search_rest_response( $c, $search, $path );

        return;
    }
}

{
    my %SearchConfig = (
        captured_path_position => 1,
        search_class           => 'VegGuide::Search::Vendor::ByLatLong',
    );

    sub by_address :
        LocalRegex('^by-address/([^/]+)(?:/filter(?:/(.*)))?$')
        : ActionClass('+VegGuide::Action::REST') { }

    sub by_address_GET : Private {
        my $self = shift;
        my $c    = shift;

        my $address = $c->request()->captures()->[0];

        my $country = ( split /,\s*/, $address )[-1];
        my $geocoder = VegGuide::Geocoder->new( country => $country );
        $geocoder ||= VegGuide::Geocoder->new( country => 'USA' );

        my $result = $geocoder->geocode_full_address($address);

        unless ($result) {
            $self->_rest_error_response(
                $c,
                "The address your provided ($address) could not be resolved to a latitude and longitude.",
                'not_found',
            );

            return;
        }

        my $unit = $geocoder->country() eq 'USA' ? 'mile' : 'km';

        my %config = %SearchConfig;
        $config{extra_params} = sub {
            return (
                latitude  => $result->latitude(),
                longitude => $result->longitude(),
                address   => $address,
                unit      => $unit,
            );
        };

        $self->_set_search_in_stash( $c, %config );

        $self->_set_cursor_params($c);

        my $search = $c->stash()->{search};

        my $path = '/search/by-address/' . uri_escape( $search->address() );

        $self->_search_rest_response( $c, $search, $path );

        return;
    }
}

sub _set_cursor_params {
    my $self = shift;
    my $c    = shift;

    my $search = $c->stash()->{search};

    my $limit = $c->request()->parameters()->{limit} || 50;
    $limit = 100 if $limit > 100;

    my $page  = $c->request()->parameters()->{page}  || 1;
    $search->set_cursor_params(
        limit => $limit,
        page  => $page,
    );

    return;
}

sub _search_rest_response {
    my $self   = shift;
    my $c      = shift;
    my $search = shift;
    my $path   = shift;

    my %rest = (
        entry_count => $search->count(),
        uri         => static_uri(
            path  => $path,
            query => {
                distance => $search->distance(),
                unit     => $search->unit(),
            },
            with_host => 1,
        )
    );

    my $vendors = $search->vendors();
    while ( my $vendor = $vendors->next() ) {
        my $entry_rest = $vendor->rest_data( include_related => 0 );
        my $distance = $vendor->distance_from(
            latitude  => $search->latitude(),
            longitude => $search->longitude(),
            unit      => $search->unit(),
        );

        my $with_units = $distance . ' ' . $search->unit();
        $with_units .= 's' unless $distance == 1;

        $entry_rest->{distance} = $with_units;

        push @{ $rest{entries} }, $entry_rest;

        $rest{region}
            ||= $vendor->location()->rest_data( include_related => 0 );
    }

    $self->_rest_response(
        $c,
        'search',
        \%rest,
    );
}

__PACKAGE__->meta()->make_immutable();

1;
