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
        latitude          => $geocode_info->{Point}{coordinates}[1],
        longitude         => $geocode_info->{Point}{coordinates}[0],
        canonical_address => $geocode_info->{address},
    };
}

1;
