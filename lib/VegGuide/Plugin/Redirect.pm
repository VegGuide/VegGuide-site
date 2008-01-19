package VegGuide::Plugin::Redirect;

use strict;
use warnings;


sub redirect
{
    my $self   = shift;
    my $uri    = shift;
    my $status = shift;

    $self->response()->redirect( $uri, $status );

    $self->detach();
}


1;
