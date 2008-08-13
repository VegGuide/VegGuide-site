package VegGuide::Controller::Error;

use strict;
use warnings;

use base 'VegGuide::Controller::DirectToView';


sub auto : Private
{
    my $self = shift;
    my $c    = shift;

    my $status = $c->request()->path() =~ m{/(\d+)$/;

    $c->response()->status($status);
}


1;

