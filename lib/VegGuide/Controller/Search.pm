package VegGuide::Controller::Search;

use strict;
use warnings;
use namespace::autoclean;

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

    sub geographical :
        LocalRegex('^geographical/(-?[\d\.]+),(-?[\d\.]+)(?:/filter(?:/(.*)))?$')
        : ActionClass('+VegGuide::Action::REST') { }

    sub geographical_GET : Private {
        my $self = shift;
        my $c    = shift;

        $self->_set_search_in_stash( $c, %SearchConfig );

        my $search = $c->stash()->{search};

        my $limit = $c->request()->parameters()->{limit} || 200;
        my $page  = $c->request()->parameters()->{page}  || 1;
        $search->set_cursor_params(
            limit => $limit,
            page  => $page,
        );

        my $path
            = '/search/geographical/'
            . $search->latitude() . ','
            . $search->longitude();

        my %rest = (
            count => $search->count(),
            uri   => static_uri(
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
}

__PACKAGE__->meta()->make_immutable();

1;
