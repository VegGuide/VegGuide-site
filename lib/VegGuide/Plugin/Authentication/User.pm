package VegGuide::Plugin::Authentication::User;

use strict;
use warnings;

use base 'Catalyst::Plugin::Authentication::User';

use VegGuide::User;


sub new
{
    my $class = shift;
    my $user  = shift;

    return bless { user => $user }, $class;
}

sub id
{
    return $_[0]->{user}->user_id();
}

sub get_object
{
    return $_[0]->{user};
}

sub from_cookie
{
    my $class   = shift;
    my $c       = shift;
    my $user_id = shift;

    return VegGuide::User->new( user_id => $user_id );
}

1;
