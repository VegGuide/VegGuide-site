package VegGuide::Cursor::VendorByAggregate;

use strict;
use warnings;

use parent 'Class::AlzaboWrapper::Cursor';

use VegGuide::Vendor;

sub next {
    my $self = shift;

    my @vals = $self->{cursor}->next;

    return unless @vals && defined $vals[0];

    # ignore aggregate value in return value
    return VegGuide::Vendor->new( vendor_id => $vals[0] );
}

1;
