package VegGuide::JSON;

use strict;
use warnings;

use JSON::XS;

{
    my $json = JSON::XS->new();
    $json->pretty(1);
    $json->utf8(1);

    sub Encode { $json->encode( $_[1] ) }

    sub Decode { $json->decode( $_[1] ) }
}

1;
