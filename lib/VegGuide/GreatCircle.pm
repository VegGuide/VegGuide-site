package VegGuide::GreatCircle;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( distance_between_points earth_radius lat_long_min_max );

use Math::Trig qw( deg2rad rad2deg great_circle_distance );

use VegGuide::Validate
    qw( validate validate_pos SCALAR_TYPE POS_INTEGER_TYPE );

my $UnitType = SCALAR_TYPE( regex => qr/^(?:mile|km)$/ );

my %EarthRadius = (
    mile => 3956,
    km   => 6371,
);

sub earth_radius {
    my ($unit) = validate_pos( @_, $UnitType );

    return $EarthRadius{$unit};
}

{
    my $spec = {
        latitude  => SCALAR_TYPE,
        longitude => SCALAR_TYPE,
        distance  => POS_INTEGER_TYPE,
        unit      => $UnitType,
    };

    sub lat_long_min_max {
        my %p = validate( @_, $spec );

        my ( $lat, $long )
            = map { deg2rad($_) } @p{qw( latitude longitude )};

        my $radius = $EarthRadius{ $p{unit} };

        my $lat_distance = $p{distance} / $radius;
        my ( $min_lat, $max_lat )
            = map { rad2deg($_) }
            ( $lat - $lat_distance, $lat + $lat_distance );

        my $long_distance = $p{distance} / ( $radius * cos($lat) );
        my ( $min_long, $max_long )
            = map { rad2deg($_) }
            ( $long - $long_distance, $long + $long_distance );

        return [ $min_lat, $max_lat, $min_long, $max_long ];
    }
}

{
    my $spec = {
        latitude1  => SCALAR_TYPE,
        longitude1 => SCALAR_TYPE,
        latitude2  => SCALAR_TYPE,
        longitude2 => SCALAR_TYPE,
        unit       => $UnitType,
    };

    sub distance_between_points {
        my %p = validate( @_, $spec );

        my ( $lat1, $lat2 )
            = map { deg2rad( 90 - $_ ) } @p{qw( latitude1 latitude2 )};

        my ( $long1, $long2 )
            = map { deg2rad($_) } @p{qw( longitude1 longitude2 )};

        return sprintf(
            '%.1f',
            great_circle_distance(
                $long1, $lat1, $long2, $lat2, $EarthRadius{ $p{unit} }
            )
        );
    }
}

1;
