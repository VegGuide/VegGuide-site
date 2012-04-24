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

done_testing();
