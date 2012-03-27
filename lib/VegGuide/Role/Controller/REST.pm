package VegGuide::Role::Controller::REST;

use strict;
use warnings;

use Moose::Role;

sub _rest_response {
    my $self      = shift;
    my $c         = shift;
    my $mime_type = shift;
    my $object    = shift;

    $c->response()->content_type($mime_type);
    $self->status_ok(
        $c,
        entity => $object->rest_data(),
    );
}

1;
