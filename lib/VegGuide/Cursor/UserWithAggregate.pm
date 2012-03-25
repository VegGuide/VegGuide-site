package VegGuide::Cursor::UserWithAggregate;

use strict;
use warnings;

use parent 'Class::AlzaboWrapper::Cursor';

use VegGuide::User;

sub next {
    my $self = shift;

    my ( $agg, $user_id ) = $self->{cursor}->next
        or return;

    return (
        $agg,
        VegGuide::User->new( user_id => $user_id )
    );
}

1;
