package VegGuide::Plugin::Authentication::Credential::DBMS;

use strict;
use warnings;

use VegGuide::User;


sub new
{
    my $class = shift;

    return bless {}, $class;
}

sub authenticate
{
    my $self  = shift;
    my $c     = shift;
    my $realm = shift;
    my $auth  = shift;

    return $realm->find_user( $auth, $c );
}


1;
