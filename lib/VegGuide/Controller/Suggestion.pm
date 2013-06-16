package VegGuide::Controller::Suggestion;

use strict;
use warnings;
use namespace::autoclean;

use VegGuide::SiteURI qw( user_uri );
use VegGuide::Vendor;

use Moose;

BEGIN { extends 'VegGuide::Controller::Base'; }

sub _set_suggestion : Chained('/') : PathPart('suggestion') : CaptureArgs(1) {
    my $self          = shift;
    my $c             = shift;
    my $suggestion_id = shift;

    $c->redirect_and_detach('/')
        unless $suggestion_id =~ /^[0-9]+$/;

    my $suggestion = VegGuide::VendorSuggestion->new(
        vendor_suggestion_id => $suggestion_id );

    $c->redirect_and_detach('/')
        unless $suggestion && $c->vg_user()->can_edit_suggestion($suggestion);

    $c->stash()->{suggestion} = $suggestion;
}

sub suggestion : Chained('_set_suggestion') : PathPart('') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub suggestion_PUT {
    my $self = shift;
    my $c    = shift;

    if ( $c->request()->param('accepted') ) {
        $c->stash()->{suggestion}->accept(
            user    => $c->vg_user(),
            comment => ( $c->request()->param('comment') || '' ),
        );
    }

    $c->redirect_and_detach(
        user_uri( user => $c->vg_user(), path => 'suggestions' ) );
}

sub suggestion_DELETE {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{suggestion}->reject(
        user    => $c->vg_user(),
        comment => ( $c->request()->param('comment') || '' ),
    );

    $c->redirect_and_detach(
        user_uri( user => $c->vg_user(), path => 'suggestions' ) );
}

__PACKAGE__->meta()->make_immutable();

1;
