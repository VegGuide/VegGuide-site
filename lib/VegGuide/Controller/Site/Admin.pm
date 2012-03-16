package VegGuide::Controller::Site::Admin;

use strict;
use warnings;

use base 'VegGuide::Controller::DirectToView';

use VegGuide::Locale;
use VegGuide::Vendor;
use VegGuide::VendorSource;

sub auto : Private {
    my $self = shift;
    my $c    = shift;

    $c->redirect_and_detach('/')
        unless $c->vg_user()->is_admin();

    return 1;
}

sub locale_list : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{locales} = VegGuide::Locale->All();
}

sub locale : Regex('^locale/(\d+)') : ActionClass('+VegGuide::Action::REST') {
}

sub locale_PUT {
    my $self = shift;
    my $c    = shift;

    my $locale = VegGuide::Locale->new(
        locale_id => $c->request()->captures()->[0] );

    my %data = $c->request()->locale_data();

    $locale->update(%data);

    $locale->replace_encodings( $c->request()->param('encodings') );

    $c->add_message( $locale->name() . ' has been updated.' );

    $c->redirect_and_detach('/site/admin/locale_list');
}

sub locales : Global : ActionClass('+VegGuide::Action::REST') {
}

sub locales_POST {
    my $self = shift;
    my $c    = shift;

    my %data = $c->request()->locale_data();

    my $locale = VegGuide::Locale->create(%data);

    $locale->replace_encodings( $c->request()->param('encodings') );

    $c->add_message( $locale->name() . ' has been created.' );

    $c->redirect_and_detach('/site/admin/locale_list');
}

sub source_list : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{sources} = VegGuide::VendorSource->All();
}

sub source : Regex('^source/(\d+)') : ActionClass('+VegGuide::Action::REST') {
}

sub source_PUT {
    my $self = shift;
    my $c    = shift;

    my $source = VegGuide::VendorSource->new(
        vendor_source_id => $c->request()->captures()->[0] );

    my %data = $c->request()->vendor_source_data();

    $source->update(%data);

    $c->add_message( $source->name() . ' has been updated.' );

    $c->redirect_and_detach('/site/admin/source_list');
}

sub sources : Global : ActionClass('+VegGuide::Action::REST') {
}

sub sources_POST {
    my $self = shift;
    my $c    = shift;

    my %data = $c->request()->vendor_source_data();

    my $source = VegGuide::VendorSource->create(%data);

    $c->add_message( $source->name() . ' has been created.' );

    $c->redirect_and_detach('/site/admin/source_list');
}

sub duplicates : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{duplicates} = VegGuide::Vendor->PossibleDuplicates();

    $c->stash()->{template} = '/site/admin/duplicates';
}

sub users_with_profiles : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{users} = VegGuide::User->All( with_profile => 1 );
}

sub debug : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/site/admin/debug';
}

1;
