package VegGuide::Cursor::VendorWithAggregate;

use strict;
use warnings;

use parent 'Class::AlzaboWrapper::Cursor';

use VegGuide::Vendor;

sub next {
    my $self = shift;

    # ignore aggregate value in return value
    my ( $agg, $vendor_id ) = $self->{cursor}->next
        or return;

    return (
        $agg,
        VegGuide::Vendor->new( vendor_id => $vendor_id )
    );
}

1;
