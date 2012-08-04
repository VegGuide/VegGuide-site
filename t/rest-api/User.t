use strict;
use warnings;

use lib 't/lib';

use Catalyst::Test 'VegGuide';
use Test::More 0.88;
use Test::VegGuide qw( json_ok path_to_uri rest_request use_test_database );

use_test_database();

{
    my $response = request( rest_request( GET => '/user/3' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-user+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    ok(
        exists $entry->{bio},
        'got bio information in the rest response'
    );

    my $bio = delete $entry->{bio};
    ok(
        exists $bio->{'text/html'},
        'bio has text/html key'
    );

    ok(
        exists $bio->{'text/vnd.vegguide.org-wikitext'},
        'bio has text/vnd.vegguide.org-wikitext key'
    );

    like(
        $bio->{'text/html'},
        qr/programmer/,
        'bio contains expected text'
    );

    like(
        $bio->{'text/html'},
        qr/<p>/,
        'bio contains HTML tags'
    );

    is_deeply(
        $entry,
        {
            name                  => 'Dave Rolsky',
            uri                   => path_to_uri('/user/3'),
            website               => 'http://blog.urth.org',
            veg_level             => 4,
            veg_level_description => 'vegan',
            image                 => {
                mime_type => 'image/jpeg',
                files     => [
                    {
                        uri    => path_to_uri('/user-images/3-small.jpg'),
                        height => 30,
                        width  => 40,
                    },
                    {
                        uri    => path_to_uri('/user-images/3-large.jpg'),
                        height => 76,
                        width  => 100,
                    },
                ],
            },
        },
        'got the expected response for a user'
    );
}

done_testing();

