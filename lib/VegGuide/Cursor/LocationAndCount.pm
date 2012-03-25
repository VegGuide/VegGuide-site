package VegGuide::Cursor::LocationAndCount;

use strict;
use warnings;

use parent 'Class::AlzaboWrapper::Cursor';

sub next {
    my $self = shift;

    my ( $count, $location_id ) = $self->{cursor}->next
        or return;

    return (
        $count,
        VegGuide::Location->new( location_id => $location_id )
    );
}

1;
