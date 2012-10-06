use strict;
use warnings;

use lib 't/lib';

use Catalyst::Test 'VegGuide';
use Test::More 0.88;
use Test::VegGuide qw( json_ok path_to_uri rest_request use_test_database );

use_test_database();

{
    my $response = request( rest_request( GET => '/entry/557' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    my $expect = {
        accepts_reservations => 0,
        address1             => '29 5th St. West',
        allows_smoking       => 0,
        categories           => ['Restaurant'],
        city                 => 'Saint Paul',
        creation_datetime    => '2004-03-03T22:20:17Z',
        cuisines             => ['Mexican'],
        hours                => [
            {
                days  => 'Mon - Fri',
                hours => ['10:30am - 4pm']
            },
            {
                days  => 'Sat - Sun',
                hours => ['closed']
            }
        ],
        is_cash_only             => 0,
        is_wheelchair_accessible => undef,
        last_modified_datetime   => '2008-04-30T17:02:52Z',
        long_description         => {
            'text/html' =>
                q{<p>Chipotle restaurants have been sprouting up across the Twin Cities everywhere you turn.  Run like a Subway, you get to choose which toppings go on your burrito and which stay off.  A delicious vegetarian burrito/fajita is offered that can include roasted green peppers, black beans, rice, a choice of various salsas, guacomole, and shredded lettuce (for non-vegans there is also sour cream and shredded cheese).  One of these monsters is enough to fill anyone's appetite and they come down to a mere $5.  Beer and fountain drinks are available, along with nachos and other appetizer type dishes.</p>}
                . "\n",
            'text/vnd.vegguide.org-wikitext' =>
                q{Chipotle restaurants have been sprouting up across the Twin Cities everywhere you turn.  Run like a Subway, you get to choose which toppings go on your burrito and which stay off.  A delicious vegetarian burrito/fajita is offered that can include roasted green peppers, black beans, rice, a choice of various salsas, guacomole, and shredded lettuce (for non-vegans there is also sour cream and shredded cheese).  One of these monsters is enough to fill anyone's appetite and they come down to a mere $5.  Beer and fountain drinks are available, along with nachos and other appetizer type dishes.},
        },
        name         => 'Chipotle',
        phone        => '651-291-5411',
        postal_code  => 55102,
        price_range  => '$ - inexpensive',
        rating_count => 4,
        region       => {
            name        => 'Twin Cities',
            is_country  => 0,
            time_zone   => 'America/Chicago',
            uri         => path_to_uri('/region/13'),
            entries_uri => path_to_uri('/region/13/entries'),
            entry_count => 116,
        },
        reviews_uri => path_to_uri('/entry/557/reviews'),
        short_description =>
            q{Sick of Taco Bell? Check out this cleaner, slightly more expensive alternative if you're fiending for a nice burrito or tacos...},
        sortable_name => 'Chipotle',
        uri           => path_to_uri('/entry/557'),
        user          => {
            name => 'GBS',
            uri  => path_to_uri('/user/112'),
        },
        veg_level             => 2,
        veg_level_description => 'Vegan-Friendly',
        website               => 'http://www.chipotle.com',
        weighted_rating       => 2.9,
    };

    is_deeply(
        $entry,
        $expect,
        'got back expected data for entry',
    );
}

{
    my $response = request( rest_request( GET => '/entry/557/reviews' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry-reviews+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $reviews = json_ok($response);

    is( scalar @{$reviews}, 4, 'got 4 reviews back' );

    delete $_->{user}{bio} for @{$reviews};

    my $expect = [
        {
            body => {
                'text/vnd.vegguide.org-wikitext' =>
                    q{I like this place, it's nice. I think it's awesome that you have to share with people in order to eat the whole thing- it lowers the cost, especially if the friend you're with has no $$. I also like that you can choose how hot you'd like the burrito. Where I live, it's either hot or...REALLY hot. I also like the fact that you can watch them make it so you know exactly what's going in it!},
                'text/html' =>
                    q{<p>I like this place, it's nice. I think it's awesome that you have to share with people in order to eat the whole thing- it lowers the cost, especially if the friend you're with has no $$. I also like that you can choose how hot you'd like the burrito. Where I live, it's either hot or...REALLY hot. I also like the fact that you can watch them make it so you know exactly what's going in it!</p>}
                    . "\n",
            },
            last_modified_datetime => '2004-12-15T18:51:41Z',
            rating                 => 4,
            user                   => {
                name                  => 'Alison Edlund',
                uri                   => path_to_uri('/user/770'),
                veg_level             => 0,
                veg_level_description => 'not telling',
            }
        },
        {
            body => {
                'text/vnd.vegguide.org-wikitext' =>
                    q{"Veggie fajita. Hot. Just guac & lettuce." Those six words garner me an adequate burrito that I can eat all day long. Chipotle is the only fast food franchise I can tolerate and I tend to get a burrito from them for lunch nearly once a week.},
                'text/html' =>
                    '<p>&quot;Veggie fajita. Hot. Just guac &amp; lettuce.&quot; Those six words garner me an adequate burrito that I can eat all day long. Chipotle is the only fast food franchise I can tolerate and I tend to get a burrito from them for lunch nearly once a week.</p>'
                    . "\n",
            },
            last_modified_datetime => '2004-06-28T23:32:28Z',
            rating                 => 3,
            user                   => {
                name                  => 'vaxjo',
                uri                   => path_to_uri('/user/225'),
                website               => 'http://jarrin.net',
                veg_level             => 4,
                veg_level_description => 'vegan',
            }
        },
        {
            body => {
                'text/vnd.vegguide.org-wikitext' =>
                    'The food is good and the prices are decent, but the portions are too much for one person. Definitely beneficial to split with a friend.',
                'text/html' =>
                    '<p>The food is good and the prices are decent, but the portions are too much for one person. Definitely beneficial to split with a friend.</p>'
                    . "\n",
            },
            last_modified_datetime => '2004-06-03T18:16:23Z',
            rating                 => 2,
            user                   => {
                name                  => 'Emily K',
                uri                   => path_to_uri('/user/446'),
                veg_level             => 0,
                veg_level_description => 'not telling',
            }
        },
        {
            rating => 1,
            user   => {
                name                  => 'Nicholas',
                uri                   => path_to_uri('/user/2370'),
                veg_level             => 0,
                veg_level_description => 'not telling',
            }
        }
    ];

    is_deeply(
        $reviews,
        $expect,
        'got expected data back for reviews'
    );
}

{
    my $response = request( rest_request( GET => '/entry/37/images' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry-images+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $images = json_ok($response);

    is( scalar @{$images}, 4, 'got 4 images back' );

    delete $_->{user}{bio} for @{$images};

    my $expect = [
        {
            mime_type => 'image/png',
            files     => [
                {
                    uri => path_to_uri('/entry-images/37/37-1983-mini.png'),
                    height => 91,
                    width  => 120,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-1983-small.png'),
                    height => 190,
                    width  => 250,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-1983-large.png'),
                    height => 190,
                    width  => 250,
                },
                {
                    uri =>
                        path_to_uri('/entry-images/37/37-1983-original.png'),
                    height => 190,
                    width  => 250,
                },
            ],
            user => {
                name => 'Admin',
                uri  => path_to_uri('/user/1'),
            },
        },
        {
            mime_type => 'image/png',
            files     => [
                {
                    uri => path_to_uri('/entry-images/37/37-1984-mini.png'),
                    height => 90,
                    width  => 120,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-1984-small.png'),
                    height => 187,
                    width  => 250,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-1984-large.png'),
                    height => 400,
                    width  => 533,
                },
                {
                    uri =>
                        path_to_uri('/entry-images/37/37-1984-original.png'),
                    height => 480,
                    width  => 640,
                },
            ],
            user => {
                name => 'Admin',
                uri  => path_to_uri('/user/1'),
            },
        },
        {
            caption   => 'Interior of restaurant.',
            mime_type => 'image/jpeg',
            files     => [
                {
                    uri => path_to_uri('/entry-images/37/37-4334-mini.jpg'),
                    height => 90,
                    width  => 120,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-4334-small.jpg'),
                    height => 187,
                    width  => 250,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-4334-large.jpg'),
                    height => 400,
                    width  => 533,
                },
                {
                    uri =>
                        path_to_uri('/entry-images/37/37-4334-original.jpg'),
                    height => 1200,
                    width  => 1600,
                },
            ],
            user => {
                name => 'conde.kedar',
                uri  => path_to_uri('/user/4795'),
            },
        },
        {
            caption   => 'Eggplant with Thai Basil',
            mime_type => 'image/jpeg',
            files     => [
                {
                    uri => path_to_uri('/entry-images/37/37-5563-mini.jpg'),
                    height => 90,
                    width  => 120,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-5563-small.jpg'),
                    height => 187,
                    width  => 250,
                },
                {
                    uri => path_to_uri('/entry-images/37/37-5563-large.jpg'),
                    height => 400,
                    width  => 533,
                },
                {
                    uri =>
                        path_to_uri('/entry-images/37/37-5563-original.jpg'),
                    height => 2304,
                    width  => 3072,
                },
            ],
            user => {
                name => 'Danielle S',
                uri  => path_to_uri('/user/8070'),
            },
        }
    ];

    is_deeply(
        $images,
        $expect,
        'got expected data back for images'
    );
}

{
    my $response = request( rest_request( GET => '/entry/997' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    for my $key (
        qw( accepts_reservations allows_smoking is_wheelchair_accessible )) {

        ok(
            exists $entry->{$key},
            "$key key exists in response"
        );

        is(
            $entry->{$key}, undef,
            "Got null for $key key"
        );
    }
}

{
    my $response = request( rest_request( GET => '/entry/954' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    is(
        $entry->{close_date},
        '2009-07-14',
        'close_date is returned as just a date'
    );
}

{
    my $response = request( rest_request( GET => '/entry/870' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    ok(
        !exists $entry->{weighted_rating},
        'no weighted_rating for this entry'
    );

    is(
        $entry->{rating_count},
        0,
        'rating_count is 0 for this entry'
    );
}

{
    my $response = request( rest_request( GET => '/entry/939' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    my @tags = (
        '(Mostly) Organic',
        'Large Group-Friendly',
        'Quiet',
        'Romantic',
        'Valet Parking',
    );

    is_deeply(
        $entry->{tags},
        \@tags,
        'got expected list of tags for entry'
    );
}

{
    my $response = request( rest_request( GET => '/entry/970' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    my @cuisines = (
        'American',
        'Chinese',
        'Deli',
        'Macrobiotic',
        'Middle Eastern/Persian',
        'Raw Food',
    );

    is_deeply(
        $entry->{cuisines},
        \@cuisines,
        'got expected list of cuisines for entry'
    );
}

done_testing();
