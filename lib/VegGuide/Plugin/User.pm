package VegGuide::Plugin::User;

use strict;
use warnings;

use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors( '_vg_user' );



sub vg_user
{
    my $self = shift;

    my $user = $self->_vg_user();

    unless ($user)
    {
        $user = $self->_get_user_from_cookie();
        $self->_vg_user($user);
    }

    return $user;
}

sub _get_user_from_cookie
{
    my $self = shift;

    my $cookie = $self->authen_cookie_value();

    my $user;
    $user = VegGuide::User->new( user_id => $cookie->{user_id} )
        if $cookie;

    return $user || VegGuide::User::Guest->new();
}

1;
