package VegGuide::VendorRating;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema->VendorRating_t );

use VegGuide::Vendor;

sub vendor { VegGuide::Vendor->new( object => $_[0]->row_object->vendor ) }

1;
