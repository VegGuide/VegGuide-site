package VegGuide::Plugin::InOutEncoding;

use strict;
use warnings;

use Encode;
use VegGuide::Util qw( string_is_empty );


sub prepare_parameters
{
    my $self = shift;

    $self->NEXT::prepare_parameters();

    # This fiddling around in the request object's internally is a bit
    # gross.
    my $p = $self->request->{parameters};

    while ( my ( $k, $v ) = each %{$p} )
    {
        next if $k =~ /_id$/;
        next if string_is_empty($v);
        next if ref $v && ! eval { @$v };

        if ( ref $v )
        {
            $p->{$k} = [ map { $self->client()->decode($_) } @$v ];
        }
        else
        {
            $v =~ s/\r\n?/\n/gs;
            $p->{$k} = $self->client()->decode($v);
        }
    }
}

sub finalize
{
    my $self = shift;

    my $body = $self->response()->body();

    unless (    $body
             && Encode::is_utf8($body)
             && $self->response()->content_type() =~ /^text/
           )
    {
        return $self->NEXT::finalize();
    }

    # Also quite gross, but this does the encoding in place.
    utf8::encode( $self->response->{body} );

    return $self->NEXT::finalize();
}


1;

