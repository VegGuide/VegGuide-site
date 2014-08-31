package Catalyst::Plugin::DR::Session::State::URI;

use strict;
use warnings;

use MRO::Compat;
use URI;

use Moose;

extends 'Catalyst::Plugin::Session::State';

has _session_id_from_uri =>
    ( is  => 'rw',
    );


# Maybe better as prepare_path?
sub prepare_action
{
    my $self = shift;

    if ( my ( $path, $id ) =
         $self->request()->path() =~ m{^ (?: (.*) / )? -/ ([0-9a-f]{40}) $}x )
    {
        $self->request()->path( defined $path ? $path : '' );
        $self->_session_id_from_uri($id);

        unless ( keys %{ $self->session() } )
        {
            $self->_session_id_from_uri(undef);
            # Intentionally not using $self->redirect() here since we can't detach() yet
            $self->response()->redirect( $self->request()->uri() );
        }
    }

    return $self->next::method(@_);
}

sub get_session_id
{
    my $self = shift;

    return $self->_session_id_from_uri();
}

sub finalize
{
    my $self = shift;

    if ( $self->response()->status()
         && $self->response()->status() == 302
         && $self->sessionid()
         && keys %{ $self->session() }
       )
    {
        my $uri = $self->_uri_with_sessionid( $self->response()->location() );

        $self->response()->location($uri);
    }

    return $self->next::method(@_)
}

sub _uri_with_sessionid
{
    my $self = shift;
    my $uri = URI->new( shift );

    my $path = $uri->path() || '';
    $path =~ s{/$}{};

    $uri->path( join '/-/', $path, $self->sessionid() );

    return $uri->canonical()->as_string();
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
