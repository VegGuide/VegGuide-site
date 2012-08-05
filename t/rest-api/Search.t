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

    my $entry = json_ok($response);

    my $uri = URI->new( $entry->{uri} );
    is(
        $uri->path(),
        '/search/by-lat-long/44.9479791,-93.2935778',
        'got expected uri path for search'
    );

    is_deeply(
        $entry->{region},
        {
            is_country  => 0,
            entries_uri => 'http://quasar:3000/region/13/entries',
            name        => 'Twin Cities',
            time_zone   => 'America/Chicago',
            uri         => 'http://quasar:3000/region/13',
            entry_count => 116,
        },
        'got Twin Cities region back for search'
    );

}

done_testing();

