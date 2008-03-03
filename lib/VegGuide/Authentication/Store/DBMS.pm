package VegGuide::Authentication::Store::DBMS;

use strict;
use warnings;

# No doubt SHA-512 is way overkill but it can't hurt (I hope).
use Digest::SHA qw( sha512_base64 );
use VegGuide::User;
use Catalyst::Authentication::User::DR;


sub new
{
    my $class = shift;

    return bless {}, $class;
}

sub find_user
{
    my $class = shift;
    my $auth  = shift;
    my $c     = shift;

    my $user = VegGuide::User->new(%$auth)
        if %$auth;

    $user ||= VegGuide::User::Guest->new();

    return Catalyst::Authentication::User::DR->new($user);
}

sub for_cookie
{
    my $class = shift;
    my $c     = shift;
    my $user  = shift;

    return { user_id => $user->id(),
             MAC     => $class->_MAC_for_user( $user->id() ),
           };
}

sub from_cookie
{
    my $class = shift;
    shift; # $c
    my $value = shift;

    return $class->find_user( {} )
        unless $value->{MAC}
        && $value->{user_id}
        && $value->{MAC} eq $class->_MAC_for_user( $value->{user_id} );

    return $class->find_user( { user_id => $value->{user_id} } );
}

sub _MAC_for_user
{
    shift; # $self or $class
    my $id = shift;

    return sha512_base64( $id, VegGuide::Config->MACSecret() );
}


1;
