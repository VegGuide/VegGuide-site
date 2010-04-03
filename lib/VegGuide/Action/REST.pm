package VegGuide::Action::REST;

use strict;
use warnings;

use base 'Catalyst::Action::REST';

use MRO::Compat;

sub dispatch {
    my $self = shift;
    my $c    = shift;

    if ( $c->request()->looks_like_browser()
        && uc $c->request()->method() eq 'GET' ) {
        my $controller = $self->class();
        my $method     = $self->name() . '_GET_html';

        if ( $controller->can($method) ) {
            $c->execute( $self->class, $self, @{ $c->req->args } );

            return $controller->$method( $c, @{ $c->request()->args() } );
        }
    }

    return $self->next::method($c);
}

1;
