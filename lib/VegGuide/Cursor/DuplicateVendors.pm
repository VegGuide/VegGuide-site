package VegGuide::Cursor::DuplicateVendors;

use strict;
use warnings;

use parent 'Class::AlzaboWrapper::Cursor';

use VegGuide::Vendor;

sub next {
    my $self = shift;

    my ( $v1_id, $v2_id ) = $self->_next_ids()
        or return;

    $self->{count} ||= 0;
    $self->{count}++;

    $self->{seen_v1}{$v1_id} = 1;

    return map { VegGuide::Vendor->new( vendor_id => $_ ) } $v1_id, $v2_id;
}

sub count { $_[0]->{count} }

sub _next_ids {
    my $self = shift;

    my ( $v1_id, $v2_id ) = $self->{cursor}->next()
        or return;

    while ( defined $v2_id && $self->{seen_v1}{$v2_id} ) {
        ( $v1_id, $v2_id ) = $self->{cursor}->next()
            or return;
    }

    $self->{seen_v1}{$v1_id} = 1;

    return ( $v1_id, $v2_id );
}

1;
