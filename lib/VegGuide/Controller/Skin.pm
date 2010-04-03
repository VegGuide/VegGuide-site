package VegGuide::Controller::Skin;

use strict;
use warnings;

use base 'VegGuide::Controller::Base';

use VegGuide::SiteURI qw( user_uri );
use VegGuide::Vendor;

sub _set_skin : Chained('/') : PathPart('skin') : CaptureArgs(1) {
    my $self    = shift;
    my $c       = shift;
    my $skin_id = shift;

    my $skin = VegGuide::Skin->new( skin_id => $skin_id );

    $c->redirect_and_detach('/')
        unless $skin && $c->vg_user()->can_edit_skin($skin);

    $c->stash()->{skin} = $skin;
}

sub edit_form : Chained('_set_skin') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/site/skin-edit-form';
}

sub skin : Chained('_set_skin') : PathPart('') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub skin_PUT {
    my $self = shift;
    my $c    = shift;

    my $skin = $c->stash()->{skin};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_edit_skin($skin);

    my %data = $c->request()->skin_data();

    delete @data{ 'owner_user_id', 'hostname' }
        unless $c->vg_user()->is_admin();

    $skin->update(%data);

    my $file = $c->request()->upload('image');

    $skin->save_image( $file->fh() )
        if $file && $file->fh();

    $c->add_message( 'The ' . $skin->hostname() . ' skin has been updated.' );

    $c->redirect_and_detach( '/skin/' . $skin->skin_id() . '/edit_form' );
}

1;
