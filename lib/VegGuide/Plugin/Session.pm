package VegGuide::Plugin::Session;

use strict;
use warnings;

use base 'Catalyst::Plugin::Session';

use VegGuide::Validate
    qw( validate validate_pos SCALAR_TYPE HASHREF_TYPE ERROR_OR_EXCEPTION_TYPE );

use HTTP::Status qw( RC_INTERNAL_SERVER_ERROR );
use VegGuide::JSON;


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
    my $spec = { error  => ERROR_OR_EXCEPTION_TYPE,
                 status => SCALAR_TYPE( default => RC_INTERNAL_SERVER_ERROR ),
                 uri    => SCALAR_TYPE,
                 params => HASHREF_TYPE( default => {} ),
               };

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
            $self->redirect_and_detach( $p{uri} );
        }
        else
        {
            my $uri = $self->uri_with_sessionid( $p{uri} );

            $self->response()->status( $p{status} );
            $self->response()->body( VegGuide::JSON->Encode( { uri => $uri } ) );
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
    my @spec = ( SCALAR_TYPE );
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
