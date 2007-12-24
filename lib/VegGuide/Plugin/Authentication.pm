package VegGuide::Plugin::Authentication;

use strict;
use warnings;

use base 'Catalyst::Plugin::Authentication';

use VegGuide::Config;


sub set_authenticated
{
    my $self       = shift;
    my $user       = shift;
    my $realm_name = shift;

    $self->NEXT::set_authenticated( $user, $realm_name );

    my $realm = $self->get_auth_realm($realm_name);

    $self->_set_user_cookie( $realm->{'store'}->for_cookie( $self, $user ) );
}

sub _set_user_cookie
{
    my $self  = shift;
    my $value = shift;

    my %cookie = ( value => $value,
                   path  => '/',
                 );

    # Unfortunately, not all of the info passed to authenticate() by
    # the controller winds up here, so we'll have to dig around to
    # determine how long to keep the cookie for.
    $cookie{expires} = '+1y'
        if $self->request()->param('remember');

    $cookie{domain} = $self->config()->{authentication}{cookie_domain}
        if $self->config()->{authentication}{cookie_domain};

    $self->response()->cookies()->{ $self->_cookie_name() } = \%cookie;
}

# The repeated hard-coding of default as the realm name is smelly. I
# wish C::P::Authentication were more amenable to different state
# mechanisms.
sub auth_restore_user
{
    my $self = shift;

    my $cookie = $self->request()->cookies()->{ $self->_cookie_name() };
    return unless $cookie && $cookie->value();

    my $realm = $self->get_auth_realm('default');
    $self->_user( my $user = $realm->{'store'}->from_cookie( $self, { $cookie->value() } ) );

    $user->auth_realm('default');

    return $user;
}

sub _cookie_name
{
    my $self = shift;

    return $self->config()->{authentication}{cookie_name};
}


1;
