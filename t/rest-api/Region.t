use strict;
use warnings;

use lib 't/lib';

use Catalyst::Test 'VegGuide';
use Test::More 0.88;
use Test::VegGuide qw( json_ok path_to_uri rest_request use_test_database );

use_test_database();

{
    my $response = request( rest_request( GET => '/region/1' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-region+json; charset=UTF-8; version='
            . $VegGuide::REST_VERSION,
        'got the right RESTful content type'
    );

    my $region = json_ok($response);

    my %expect = (
        name        => 'North America',
        uri         => path_to_uri('/region/1'),
        entries_uri => path_to_uri('/region/1/entries'),
        entry_count => 0,
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
                name        => 'Canada',
                is_country  => 1,
                uri         => path_to_uri('/region/19'),
                entries_uri => path_to_uri('/region/19/entries'),
                entry_count => 0,
            },
            {
                name        => 'Mexico',
                is_country  => 1,
                locale      => 'es_MX',
                uri         => path_to_uri('/region/25'),
                entries_uri => path_to_uri('/region/25/entries'),
                entry_count => 0,
            },
            {
                name        => 'USA',
                is_country  => 1,
                uri         => path_to_uri('/region/2'),
                entries_uri => path_to_uri('/region/2/entries'),
                entry_count => 1,
            },
        ],
        'region has Canada, Mexico, and USA as children',
    );
}

{
    my $response = request( rest_request( GET => '/region/4' ) );

    my $region = json_ok($response);

    my %expect = (
        name        => 'New York City',
        is_country  => 0,
        time_zone   => 'America/New_York',
        uri         => path_to_uri('/region/4'),
        entries_uri => path_to_uri('/region/4/entries'),
        entry_count => 0,
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
                    'text/vnd.vegguide.org-wikitext' =>
                        '[http://www.supervegan.com|Super Vegan] is an awesome site "by vegans for vegans" with NYC related news and NYC restaurant guide.',
                    'text/html' =>
                        '<p><a rel="nofollow" href="http://www.supervegan.com">Super Vegan</a> is an awesome site &quot;by vegans for vegans&quot; with NYC related news and NYC restaurant guide.</p>'
                        . "\n",
                },
                last_modified_datetime => '2008-03-22T18:36:33Z',
                user                   => {
                    name                  => 'banu',
                    uri                   => path_to_uri('/user/4126'),
                    veg_level             => 0,
                    veg_level_description => 'not telling',
                },
            },
            {
                body => {
                    'text/vnd.vegguide.org-wikitext' =>
                        'NYC has many restaurants which are cash only.  Please be aware that this is the norm, especially in Chinatown.',
                    'text/html' =>
                        '<p>NYC has many restaurants which are cash only.  Please be aware that this is the norm, especially in Chinatown.</p>'
                        . "\n",
                },
                last_modified_datetime => '2005-04-27T15:59:02Z',
                user                   => {
                    name                  => 'inah',
                    uri                   => path_to_uri('/user/18'),
                    veg_level             => 0,
                    veg_level_description => 'not telling',
                },
            },
        ],
        'got the expected comments'
    );
}

{
    my $response = request( rest_request( GET => '/region/116/entries' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entries+json; charset=UTF-8; version='
            . $VegGuide::REST_VERSION,
        'got the right RESTful content type'
    );

    my $entries = json_ok($response);

    is(
        scalar @{ $entries || [] },
        12,
        'got 12 entries'
    );

    is(
        $entries->[0]{name},
        'Alberta Co-op Grocery',
        'first entry is Alberta Co-op Grocery'
    );
}

{
    my $response = request( rest_request( GET => '/region/13/entries' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entries+json; charset=UTF-8; version='
            . $VegGuide::REST_VERSION,
        'got the right RESTful content type'
    );

    my $entries = json_ok($response);

    is(
        scalar @{ $entries || [] },
        116,
        'got 116 (open) entries'
    );
}

done_testing();
