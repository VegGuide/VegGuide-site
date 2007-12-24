package VegGuide::Controller::DirectToView;

use strict;
use warnings;

use base 'VegGuide::Controller::Base';


sub auto : Private
{
    my $self = shift;
    my $c    = shift;

    return 1 if $self->action_for( $c->action() );

    my $uri = $c->request()->uri();

    $c->response()->breadcrumbs()->add
        ( uri   => $uri,
          label => $self->_breadcrumb_title($uri),
        );

    return 1;
}

sub _breadcrumb_title
{
    my $self = shift;
    my $uri  = shift;

    my ($prefix) = lc( ref $self ) =~ /::(\w+)$/;

    my $path = $uri->path();
    $path =~ s{^/$prefix/}{};

    $path =~ s/_/ /g;

    return ucfirst $path;
}

sub default : Private
{
    my $self = shift;
    my $c    = shift;

    my $path = $c->request()->uri()->path();
    $c->stash()->{template} = $path
        if $c->view()->has_template_for_path($path);

    return 1;
}


1;
