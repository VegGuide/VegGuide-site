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
        'application/vnd.vegguide.org-entry+json; charset=UTF-8; version=0.1',
        'got the right RESTful content type'
    );

    my $entry = json_ok($response);

    my $expect = {
        accepts_reservations => 0,
        address1             => '29 5th St. West',
        address2             => undef,
        allows_smoking       => 0,
        categories           => ['Restaurant'],
        city                 => 'Saint Paul',
        close_date           => undef,
        creation_datetime    => '2004-03-03T22:20:17Z',
        cuisines             => ['Mexican'],
        directions           => undef,
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
        is_cash_only                => 0,
        is_wheelchair_accessible    => undef,
        last_modified_datetime      => '2008-04-30T17:02:52Z',
        localized_address1          => undef,
        localized_address2          => undef,
        localized_city              => undef,
        localized_long_description  => undef,
        localized_name              => undef,
        localized_neighborhood      => undef,
        localized_region            => undef,
        localized_short_description => undef,
        long_description =>
            q{Chipotle restaurants have been sprouting up across the Twin Cities everywhere you turn.  Run like a Subway, you get to choose which toppings go on your burrito and which stay off.  A delicious vegetarian burrito/fajita is offered that can include roasted green peppers, black beans, rice, a choice of various salsas, guacomole, and shredded lettuce (for non-vegans there is also sour cream and shredded cheese).  One of these monsters is enough to fill anyone's appetite and they come down to a mere $5.  Beer and fountain drinks are available, along with nachos and other appetizer type dishes.},
        name         => 'Chipotle',
        neighborhood => undef,
        phone        => '651-291-5411',
        postal_code  => 55102,
        price_range  => '$ - inexpensive',
        rating_count => 4,
        region       => {
            name        => 'Twin Cities',
            uri         => path_to_uri('/region/13'),
            entries_uri => path_to_uri('/region/13/entries'),
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
        website               => 'www.chipotle.com',
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
        'application/vnd.vegguide.org-entry-reviews+json; charset=UTF-8; version=0.1',
        'got the right RESTful content type'
    );

    my $reviews = json_ok($response);

    is( scalar @{$reviews}, 4, 'got 4 reviews back' );

    my $expect = [
        {
            body => {
                content =>
                    q{I like this place, it's nice. I think it's awesome that you have to share with people in order to eat the whole thing- it lowers the cost, especially if the friend you're with has no $$. I also like that you can choose how hot you'd like the burrito. Where I live, it's either hot or...REALLY hot. I also like the fact that you can watch them make it so you know exactly what's going in it!},
                content_type => 'text/vnd.vegguide.org-wikitext',
            },
            last_modified_datetime => '2004-12-15T18:51:41Z',
            rating                 => 4,
            user                   => {
                name => 'Alison Edlund',
                uri  => path_to_uri('/user/770'),
            }
        },
        {
            body => {
                content =>
                    q{"Veggie fajita. Hot. Just guac & lettuce." Those six words garner me an adequate burrito that I can eat all day long. Chipotle is the only fast food franchise I can tolerate and I tend to get a burrito from them for lunch nearly once a week.},
                content_type => 'text/vnd.vegguide.org-wikitext',
            },
            last_modified_datetime => '2004-06-28T23:32:28Z',
            rating                 => 3,
            user                   => {
                name => 'vaxjo',
                uri  => path_to_uri('/user/225'),
            }
        },
        {
            body => {
                content =>
                    'The food is good and the prices are decent, but the portions are too much for one person. Definitely beneficial to split with a friend.',
                content_type => 'text/vnd.vegguide.org-wikitext',
            },
            last_modified_datetime => '2004-06-03T18:16:23Z',
            rating                 => 2,
            user                   => {
                name => 'Emily K',
                uri  => path_to_uri('/user/446'),
            }
        },
        {
            body                   => { content => undef },
            last_modified_datetime => undef,
            rating                 => 1,
            review                 => undef,
            user                   => {
                name => 'Nicholas',
                uri  => path_to_uri('/user/2370'),
            }
        }
    ];

    is_deeply(
        $reviews,
        $expect,
        'got expected data back for reviews'
    );
}

done_testing();
