use strict;
use warnings;

use Test::More;
use VegGuide::Config;

BEGIN
{
    use Test::MockObject;
    Test::MockObject->new()->fake_module('Geo::Coder::Google');
}

# Needs to load after fake Geo::Coder::Google at bottom of test file
# is compiled.
require VegGuide::Geocoder;

my %addresses = address_test_data();
plan tests => 1 + ( scalar keys %addresses ) * 4;


NEW:
{
    ok( ! VegGuide::Geocoder->new( country => 'does not exist' ),
        'Cannot make Geocoder for an invalid country' );

    for my $c ( sort keys %addresses )
    {
        ok( VegGuide::Geocoder->new( country => $c ),
            "Can make Geocoder for $c" );
    }
}

GEOCODE:
{
    for my $c ( sort keys %addresses )
    {
        my $geocoder = VegGuide::Geocoder->new( country => $c );

        my ( $lat, $long ) =
            $geocoder->geocode( %{ $addresses{$c}{address} } );

        is( $lat, $addresses{$c}{expect}{lat},
            "lat for $c is $addresses{$c}{expect}{lat}" );
        is( $long, $addresses{$c}{expect}{long},
            "long for $c is $addresses{$c}{expect}{long}" );
    }
}

ADDRESS_PROCESSING:
{
    for my $c ( sort keys %addresses )
    {
        my $geocoder = VegGuide::Geocoder->new( country => $c );

        my $meth = $geocoder->{method};
        my $address = $geocoder->$meth( %{ $addresses{$c}{address} } );

        is( $address, $addresses{$c}{expect}{processed},
            "address processing for $c" );
    }
}


sub address_test_data
{
    return
        ( 'United States' =>
          { address => { address     => '2600 Emerson Ave S',
                         city        => 'Minneapolis',
                         region      => 'MN',
                         postal_code => '55408-1234',
                       },
            expect => { lat       =>  44.955565,
                        long      => -93.294425,
                        processed => '2600 Emerson Ave S, Minneapolis, MN 55408',
                      },
          },
          'Australia'     =>
          { address => { address     => '27 King Street',
                         city        => 'Sydney',
                         region      => 'New South Wales',
                         postal_code => '2000'
                       },
            expect => { lat       => -25.335448,
                        long      => 135.745076,
                        processed => '27 King Street, Sydney, New South Wales 2000',
                      },
          },
          'Canada',
          { address => { address     => '254 Spadina Avenue',
                         city        => 'Toronto',
                         region      => 'Ontario',
                         postal_code => 'M5T 2E2',
                         },
            expect => { lat       =>  43.651664,
                        long      => -79.397848,
                        processed => '254 Spadina Avenue, Toronto, Ontario M5T 2E2',
                      },
          },
          'Japan' =>
          { address => { address           => 'Ginza Kosaka buildings 7-9F, 6-9-4 Ginza',
                         localized_address => '銀座小坂ビル7〜9F, 銀座',
                         city              => 'Ginza',
                         localized_city    => '銀座',
                         region            => 'Chou-Ku',
                         localized_region  => '中区央',
                       },
            expect => { lat       => 123,
                        long      => 456,
                        processed => '中区央, 銀座',
                      },
          },
        );
}


package Geo::Coder::Google;


sub new
{
    return bless {}, shift;
}

sub geocode
{
    my $self    = shift;
    my $address = shift;

    my @coords =
        ( [ qr/\Q2600 Emerson/ => [ 44.955565, -93.294425 ] ],
          [ qr/\Q27 King/      => [ -25.335448, 135.745076 ] ],
          [ qr/\Q254 Spadina/  => [ 43.651664, -79.397848 ] ],
          [ qr/\Q中区央/        => [ 123, 456 ] ],
        );

    for my $pair (@coords)
    {
        if ( $address =~ $pair->[0] )
        {
            return $self->_fake_return( @{ $pair->[1] } );
        }
    }

    return $self->_fake_return();
}

sub _fake_return
{
    shift;
    my $lat  = shift;
    my $long = shift;

    return { Point => { coordinates => [ $long, $lat ] } };
}
