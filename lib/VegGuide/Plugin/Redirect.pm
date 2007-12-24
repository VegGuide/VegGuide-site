package VegGuide::Plugin::Redirect;

use strict;
use warnings;


sub redirect
{
    my $self = shift;
    my $uri  = shift;

    $self->response()->redirect($uri);

    $self->detach();
}


1;
