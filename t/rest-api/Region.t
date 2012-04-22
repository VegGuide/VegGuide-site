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

    is(
        scalar @{ $region->{comments} || [] },
        0,
        'region has 0 comments',
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

{
    my $response = request( rest_request( GET => '/region/4' ) );

    my $region = json_ok($response);

    my %expect = (
        name => 'New York City',
        uri  => '/region/4',
    );

    for my $key ( sort keys %expect ) {
        is(
            $region->{$key},
            $expect{$key},
            "response included the correct value for $key"
        );
    }

    is(
        scalar @{ $region->{comments} || [] },
        2,
        'region has 2 comments',
    );

    is_deeply(
        $region->{comments},
        [
            {
                body => {
                    content =>
                        '[http://www.supervegan.com|Super Vegan] is an awesome site "by vegans for vegans" with NYC related news and NYC restaurant guide.',
                    content_type => 'text/vnd.vegguide.org-wikitext',
                },
                last_modified_datetime => '2008-03-22T18:36:33Z',
                user                   => {
                    name => 'banu',
                },
            },
            {
                body => {
                    content =>
                        'NYC has many restaurants which are cash only.  Please be aware that this is the norm, especially in Chinatown.',
                    content_type => 'text/vnd.vegguide.org-wikitext',
                },
                last_modified_datetime => '2005-04-27T15:59:02Z',
                user                   => {
                    name => 'inah',
                },
            },
        ],
        'got the expected comments'
    );
}

done_testing();
