package Catalyst::Plugin::DR::Session;

use strict;
use warnings;

use base 'Catalyst::Plugin::Session';

use Params::Validate
    qw( validate validate_pos SCALAR HASHREF OBJECT );

use HTTP::Status qw( RC_OK );
use JSON::XS;
use Scalar::Util qw( blessed );


sub session
{
    my $self = shift;

    unless ( $self->_session() )
    {
        $self->_load_session();
        $self->_session( {} )
            unless $self->_session();
    }

    return $self->_session();
}

sub session_for_writing
{
    my $self = shift;

    $self->create_new_session_if_needed();

    return $self->session();
}

sub create_new_session_if_needed
{
    my $self = shift;

    return if $self->sessionid();

    $self->create_session_id_if_needed();
    $self->initialize_session_data();
}

{
    my $spec = { error  =>
                 { callbacks =>
                   { 'is a scalar or exception object' =>
                     sub { return 1 unless ref $_[0];
                           return 1 if eval { @{ $_[0] } } && ! grep { ref } @{ $_[0] };
                           return 0 unless blessed $_[0];
                           return 1 if $_[0]->can('messages') || $_[0]->can('message');
                           return 0;
                         },
                   },
                 },
                 uri    => { type => SCALAR | OBJECT },
                 params => { type => HASHREF, default => {} },
               };

    my $JSON = JSON::XS->new();
    $JSON->pretty(1);
    $JSON->utf8(1);

    sub _redirect_with_error
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        if ( eval { $p{error}->can('messages') } && $p{error}->messages() )
        {
            $self->add_error_message($_) for $p{error}->messages();
        }
        elsif ( eval { $p{error}->can('message') } )
        {
            $self->add_error_message( $p{error}->message() );
        }
        elsif ( ref $p{error} )
        {
            $self->add_error_message($_) for @{ $p{error} };
        }
        else
        {
            # force stringification
            $self->add_error_message( "$p{error}" );
        }

        my $session = $self->session_for_writing();
        while ( my ( $k, $v ) = each %{ $p{params} } )
        {
            $session->{saved_params}{$k} = $v;
        }

        if ( $self->request()->looks_like_browser() )
        {
            $self->redirect_and_detach(
                $self->uri_with_sessionid( $p{uri} ) );
        }
        else
        {
            my $uri = $self->uri_with_sessionid( $p{uri} );

            $self->response()->status(RC_OK);
            # JSON::XS does not like URI objects
            $self->response()->body( $JSON->encode( { uri => $uri . q{} } ) );
            $self->detach();
        }
    }
}

sub save_param
{
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    $self->session_for_writing()->{saved_params}{$key} = $val;
}

{
    my @spec = ( { type => SCALAR | HASHREF } );
    sub add_error_message
    {
        my $self = shift;
        my ($e)  = validate_pos( @_, @spec );

        push @{ $self->session_for_writing()->{errors} }, $e;
    }

    sub add_message
    {
        my $self = shift;
        my ($m)  = validate_pos( @_, @spec );

        push @{ $self->session_for_writing()->{messages} }, $m;
    }
}



1;
