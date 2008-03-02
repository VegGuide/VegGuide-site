package VegGuide::Geocoder;

use strict;
use warnings;

use Geo::Coder::Google;
use VegGuide::Config;
use VegGuide::Util qw( string_is_empty );
use VegGuide::Validate qw( validate SCALAR_TYPE );


my %Geocoders =
    ( map
      { lc $_->[0] =>
        { geocoder =>
          Geo::Coder::Google->new
              ( host   => $_->[1],
                apikey => VegGuide::Config->GoogleAPIKey(),
              ),
          hostname => $_->[1],
          country  => $_->[0],
        }
      }
      [ 'Australia'      => 'maps.google.com.au' ],
      [ 'Austria'        => 'maps.google.com' ],
      [ 'Belgium'        => 'maps.google.com' ],
      [ 'Brazil'         => 'maps.google.com' ],
      [ 'Canada'         => 'maps.google.ca' ],
      [ 'Czech Republic' => 'maps.google.com' ],
      [ 'Denmark'        => 'maps.google.dk' ],
      [ 'Finland'        => 'maps.google.fi' ],
      [ 'France'         => 'maps.google.fr' ],
      [ 'Germany'        => 'maps.google.de' ],
      [ 'Hong Kong'      => 'maps.google.com' ],
      [ 'Hungary'        => 'maps.google.com' ],
      [ 'India'          => 'maps.google.com' ],
      [ 'Ireland'        => 'maps.google.com' ],
      [ 'Italy'          => 'maps.google.it' ],
      [ 'Japan'          => 'maps.google.co.jp' ],
      [ 'Luxembourg'     => 'maps.google.com' ],
      [ 'Netherlands'    => 'maps.google.nl' ],
      [ 'New Zealand'    => 'maps.google.com' ],
      [ 'Poland'         => 'maps.google.com' ],
      [ 'Portugal'       => 'maps.google.com' ],
      [ 'Singapore'      => 'maps.google.com' ],
      [ 'Spain'          => 'maps.google.es' ],
      [ 'Sweden'         => 'maps.google.se' ],
      [ 'Switzerland'    => 'maps.google.com' ],
      [ 'Taiwan'         => 'maps.google.com.tw' ],
      [ 'United Kingdom' => 'maps.google.com' ],
      [ 'USA'            => 'maps.google.com' ],
    );

{
    my $spec = { country => SCALAR_TYPE };
    sub new
    {
        my $class = shift;
        my %p     = validate( @_, $spec );

        my $country = lc $p{country};

        $country = 'usa'
            if $country =~ /^(?:US|United States)/i;

        return unless $Geocoders{$country};

        my $meth = '_' . $country . '_geocode_address';
        $meth =~ s/ /_/g;

        $meth = $class->can($meth) || '_standard_geocode_address';

        return bless { geocoder => $Geocoders{$country}{geocoder},
                       hostname => $Geocoders{$country}{hostname},
                       country  => $Geocoders{$country}{country},
                       method   => $meth,
                     };
    }
}

sub Countries
{
    return map { $_->{country} } values %Geocoders;
}

{
    my $spec = { address1           => SCALAR_TYPE( optional => 1 ),
                 localized_address1 => SCALAR_TYPE( optional => 1 ),
                 city               => SCALAR_TYPE( optional => 1 ),
                 localized_city     => SCALAR_TYPE( optional => 1 ),
                 region             => SCALAR_TYPE( optional => 1 ),
                 localized_region   => SCALAR_TYPE( optional => 1 ),
                 postal_code        => SCALAR_TYPE( optional => 1 ),
               };
    sub geocode
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $meth = $self->{method};
        my $address = $self->$meth(%p)
            or return;

        return $self->geocode_full_address($address);
    }
}

sub geocode_full_address
{
    my $self = shift;
    my $address = shift;

    return VegGuide::Geocoder::Result->new( $self->{geocoder}->geocode($address) );
}

sub hostname
{
    my $self = shift;

    return $self->{hostname};
}

sub country
{
    my $self = shift;

    return $self->{country};
}

sub _united_states_geocode_address
{
    my $self = shift;
    my %p    = @_;

    if ( defined $p{postal_code} && length $p{postal_code} )
    {
        $p{postal_code} =~ s/^(\d{5}).+/$1/
    }

    return $self->_standard_geocode_address(%p);
}

sub _standard_geocode_address
{
    my $self = shift;
    my %p    = @_;

    my @pieces;
    if ( string_is_empty( $p{postal_code} ) )
    {
        @pieces = qw( address1 city region );
    }
    else
    {
        @pieces = qw( address1 postal_code );
    }

    my $address = join ', ', grep { ! string_is_empty(@_) } @p{@pieces};

    $address .= ', ' . $self->country();

    return $address;
}

sub _japan_geocode_address
{
    my $self = shift;
    my %p    = @_;

    # Remove things like building name and floors. I'm not sure how
    # correct this is, but it worked for Nataraj in Ginza. The Japan
    # geocoding needs more data and someone who knows something about
    # Japanese addresses!
    my $address = $p{localized_address1};

    return unless defined $address;

    $address =~ s/^[^,]+,\s*//;

    return
        ( join ', ',
          grep { defined }
          $p{localized_region}, $address
        );
}

sub _taiwan_geocode_address
{
    my $self = shift;
    my %p    = @_;

    my $address = $p{localized_address1};

    return unless defined $address;

    $address =~ s/^[^,]+,\s*//;

    return
        ( join ', ',
          grep { defined }
          $p{localized_city}, $address
        );
}


package VegGuide::Geocoder::Result;


for my $meth ( qw( latitude longitude canonical_address ) )
{
    my $sub = sub { return $_[0]->{$meth} };
    no strict 'refs';
    *{$meth} = $sub;
}

sub new
{
    my $class        = shift;
    my $geocode_info = shift;

    return unless $geocode_info;

    return bless { latitude          => $geocode_info->{Point}{coordinates}[1],
                   longitude         => $geocode_info->{Point}{coordinates}[0],
                   canonical_address => $geocode_info->{address},
                 };
}


1;

