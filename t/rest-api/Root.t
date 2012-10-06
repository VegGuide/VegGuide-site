use strict;
use warnings;

use lib 't/lib';

use Catalyst::Test 'VegGuide';
use List::AllUtils qw( first );
use Test::More 0.88;
use Test::VegGuide qw( json_ok path_to_uri rest_request use_test_database );

use_test_database();

{
    my $response = request( rest_request( GET => '/' ) );

    is( $response->code(), '200', 'got a 200 response' );

    is(
        $response->header('Content-Type'),
        'application/vnd.vegguide.org-root-regions+json; charset=UTF-8; version='
            . $VegGuide::REST_VERSION,
        'got the right RESTful content type'
    );

    my $regions = json_ok($response);

    ok( exists $regions->{regions}{$_}, "root region list has $_ key" )
        for qw( primary secondary );

    my $na = first { $_->{name} eq 'North America' }
    @{ $regions->{regions}{primary} };

    my $children = delete $na->{children};
    ok(
        scalar @{$children},
        'North America data includes child regions'
    );

    my %expect = (
        name        => 'North America',
        is_country  => 0,
        uri         => path_to_uri('/region/1'),
        entries_uri => path_to_uri('/region/1/entries'),
        entry_count => 0,
    );

    is_deeply(
        $na,
        \%expect,
        'got expected data for North America'
    );
}

done_testing();
