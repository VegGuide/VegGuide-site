use strict;
use warnings;

use lib 't/lib';

use Catalyst::Test 'VegGuide';
use Test::More 0.88;
use Test::VegGuide qw( json_ok path_to_uri rest_request use_test_database );

use URI;

use_test_database();

{
    my $response = request(
        rest_request(
            GET => '/search/by-lat-long/44.9479791,-93.2935778?distance=1'
        )
    );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-search+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $search = json_ok($response);

    my $uri = URI->new( $search->{uri} );
    is(
        $uri->path(),
        '/search/by-lat-long/44.9479791,-93.2935778',
        'got expected uri path for search'
    );

    is_deeply(
        $search->{region},
        {
            is_country  => 0,
            entries_uri => path_to_uri('/region/13/entries'),
            name        => 'Twin Cities',
            time_zone   => 'America/Chicago',
            uri         => path_to_uri('/region/13'),
            entry_count => 116,
        },
        'got Twin Cities region back for search'
    );

    is(
        scalar @{ $search->{entries} },
        23,
        'got 23 entries back'
    );

    is(
        $search->{entry_count},
        23,
        'entry_count is same as the number of entries returned'
    );

    my $entry = $search->{entries}[0];

    is(
        $entry->{distance},
        '0.2 miles',
        'entry data has a distance key with the expected value'
    );
}

{
    my $response = request(
        rest_request(
            GET => '/search/by-lat-long/44.9479791,-93.2935778?distance=1;limit=5'
        )
    );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-search+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $search = json_ok($response);

    is(
        scalar @{ $search->{entries} },
        5,
        'got 5 entries back'
    );

    is(
        $search->{entry_count},
        23,
        'entry_count is all of the entries returned'
    );
}

done_testing();

