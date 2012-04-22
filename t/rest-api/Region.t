use strict;
use warnings;

use lib 't/lib';

use Catalyst::Test 'VegGuide';
use Test::More 0.88;
use Test::VegGuide qw( json_ok rest_request use_test_database );

use HTTP::Request;
use VegGuide::JSON;

use_test_database();

{
    my $response = request( rest_request( GET => '/region/1' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-region+json;charset=UTF-8',
        'got the right RESTful content type'
    );

    my $region = json_ok($response);

    my %expect = (
        name => 'North America',
        uri  => '/region/1',
    );

    for my $key ( sort keys %expect ) {
        is(
            $region->{$key},
            $expect{$key},
            "response included the correct value for $key"
        );
    }

    is(
        scalar @{ $region->{children} || [] },
        3,
        'region has 3 children',
    );

    is_deeply(
        $region->{children},
        [
            {
                name => 'Canada',
                uri  => '/region/19',
            },
            {
                name => 'Mexico',
                uri  => '/region/25',
            },
            {
                name => 'USA',
                uri  => '/region/2',
            },
        ],
        'region has Canada, Mexico, and USA as children',
    );
}

done_testing();
