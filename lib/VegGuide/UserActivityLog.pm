package VegGuide::UserActivityLog;

use strict;
use warnings;

use DateTime::Format::MySQL;
use VegGuide::Location;
use VegGuide::Schema;
use VegGuide::Vendor;

use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema()->UserActivityLog_t() );

sub datetime {
    DateTime::Format::MySQL->parse_datetime( $_[0]->activity_datetime );
}

sub type {
    $_[0]->row_object->type->select('type');
}

sub vendor {
    my $self = shift;

    return unless defined $self->vendor_id;

    return VegGuide::Vendor->new( object => $self->row_object->vendor );
}

sub location {
    my $self = shift;

    return unless defined $self->location_id;

    return VegGuide::Location->new( object => $self->row_object->location );
}

1;
