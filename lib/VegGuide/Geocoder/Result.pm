package VegGuide::Geocoder::Result;

use strict;
use warnings;

use List::AllUtils qw( any );

for my $meth (qw( latitude longitude canonical_address country_code )) {
    my $sub = sub { return $_[0]->{$meth} };
    no strict 'refs';
    *{$meth} = $sub;
}

sub new {
    my $class        = shift;
    my $geocode_info = shift;

    return unless $geocode_info;

    my $country_code;
    for my $component ( @{ $geocode_info->{address_components} } ) {
        next unless any { $_ eq 'country' } @{ $component->{types} };

        $country_code = $component->{short_name};
        last;
    }

    $country_code //= 'US';

    return bless {
        latitude          => $geocode_info->{geometry}{location}{lat},
        longitude         => $geocode_info->{geometry}{location}{lng},
        canonical_address => $geocode_info->{formatted_address},
        country_code      => $country_code,
    };
}

1;
