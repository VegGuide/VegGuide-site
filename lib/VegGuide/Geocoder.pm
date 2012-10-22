package VegGuide::Geocoder;

use strict;
use warnings;

use Geo::Coder::Google 0.06;
use Locale::Country 3.23 qw( country2code );
use VegGuide::Config;
use VegGuide::Geocoder::Result;
use VegGuide::Util qw( string_is_empty );
use VegGuide::Validate qw( validate SCALAR_TYPE );

{
    my $spec = {
        country => SCALAR_TYPE,
    };

    sub new {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $country = $p{country} // 'USA';

        $country = 'USA'
            if $country =~ /^(?:US|United States)/i;

        my $meth = '_' . ( lc $country ) . '_geocode_address';
        $meth =~ s/ /_/g;

        $meth = $class->can($meth) || '_standard_geocode_address';

        return bless {
            method  => $meth,
            country => $country,
            cctld   => $class->_cctld_for_country($country),
        };
    }
}

{
    my %exception = (
        gb => 'uk',
    );

    sub _cctld_for_country {
        shift;
        my $country = shift;

        my $code = country2code($country);
        return undef unless $code;

        return $exception{$code} // $code;
    }
}

{
    my $spec = {
        address1           => SCALAR_TYPE( optional => 1 ),
        localized_address1 => SCALAR_TYPE( optional => 1 ),
        city               => SCALAR_TYPE( optional => 1 ),
        localized_city     => SCALAR_TYPE( optional => 1 ),
        region             => SCALAR_TYPE( optional => 1 ),
        localized_region   => SCALAR_TYPE( optional => 1 ),
        postal_code        => SCALAR_TYPE( optional => 1 ),
    };

    sub geocode {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $meth    = $self->{method};
        my $address = $self->$meth(%p)
            or return;

        return $self->geocode_full_address($address);
    }
}

sub geocode_full_address {
    my $self    = shift;
    my $address = shift;

    my %region;
    $region{region} = $self->{cctld}
        if $self->{cctld};

    my $geocoder = Geo::Coder::Google->new(
        apiver => 3,
        key    => VegGuide::Config->GoogleAPIKey(),
        %region,
    );

    return VegGuide::Geocoder::Result->new( $geocoder->geocode($address) );
}

sub country {
    my $self = shift;

    return $self->{country};
}

sub _united_states_geocode_address {
    my $self = shift;
    my %p    = @_;

    if ( defined $p{postal_code} && length $p{postal_code} ) {
        $p{postal_code} =~ s/^(\d{5}).+/$1/;
    }

    return $self->_standard_geocode_address(%p);
}

sub _standard_geocode_address {
    my $self = shift;
    my %p    = @_;

    my @pieces;
    if ( string_is_empty( $p{postal_code} ) ) {
        @pieces = qw( address1 city region );
    }
    else {
        @pieces = qw( address1 postal_code );
    }

    my $address = join ', ', grep { !string_is_empty($_) } @p{@pieces};

    $address .= ', ' . $self->country();

    return $address;
}

sub _japan_geocode_address {
    my $self = shift;
    my %p    = @_;

    # Remove things like building name and floors. I'm not sure how
    # correct this is, but it worked for Nataraj in Ginza. The Japan
    # geocoding needs more data and someone who knows something about
    # Japanese addresses!
    my $address = $p{localized_address1};

    return unless defined $address;

    $address =~ s/^[^,]+,\s*//;

    return (
        join ', ',
        grep { defined }
            $p{localized_region}, $address
    );
}

sub _taiwan_geocode_address {
    my $self = shift;
    my %p    = @_;

    my $address = $p{localized_address1};

    return unless defined $address;

    $address =~ s/^[^,]+,\s*//;

    return (
        join ', ',
        grep { defined }
            $p{localized_city}, $address
    );
}

1;
