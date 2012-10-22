package VegGuide::Geocoder::Result;

use strict;
use warnings;

for my $meth (qw( latitude longitude canonical_address )) {
    my $sub = sub { return $_[0]->{$meth} };
    no strict 'refs';
    *{$meth} = $sub;
}

sub new {
    my $class        = shift;
    my $geocode_info = shift;

    return unless $geocode_info;

    return bless {
        latitude  => $geocode_info->{results}{geometry}{location}{lat},
        longitude => $geocode_info->{results}{geometry}{location}{lng},
        canonical_address => $geocode_info->{formatted_address},
    };
}

1;
