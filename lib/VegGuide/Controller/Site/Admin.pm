package VegGuide::Controller::Site::Admin;

use strict;
use warnings;

use base 'VegGuide::Controller::DirectToView';

use VegGuide::Locale;


sub auto : Private
{
    my $self = shift;
    my $c    = shift;

    $c->redirect('/')
        unless $c->vg_user()->is_admin();

    return 1;
}

sub locale_list : Local
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{locales} = VegGuide::Locale->All();
}

sub locale : Regex('^locale/(\d+)') : ActionClass('+VegGuide::Action::REST') { }

sub locale_PUT
{
    my $self = shift;
    my $c    = shift;

    my $locale = VegGuide::Locale->new( locale_id => $c->request()->captures()->[0] );

    my %data = $c->request()->locale_data();

    $locale->update(%data);

    $locale->replace_encodings( $c->request()->param('encodings') );

    $c->add_message( $locale->name() . ' has been updated.' );

    $c->redirect( '/site/admin/locale_list' );
}

sub locales : Global : ActionClass('+VegGuide::Action::REST') { }

sub locales_POST
{
    my $self = shift;
    my $c    = shift;

    my %data = $c->request()->locale_data();

    my $locale = VegGuide::Locale->create(%data);

    $locale->replace_encodings( $c->request()->param('encodings') );

    $c->add_message( $locale->name() . ' has been created.' );

    $c->redirect( '/site/admin/locale_list' );
}


1;
