package VegGuide::Controller::Base;

use strict;
use warnings;
use namespace::autoclean;

use Alzabo::Runtime::UniqueRowCache;
use HTTP::Status qw( RC_FORBIDDEN );
use List::AllUtils qw( any );
use URI::Escape qw( uri_unescape );
use URI::FromHash qw( uri );
use VegGuide::AlzaboWrapper;
use VegGuide::JSON;
use VegGuide::SiteURI qw( site_uri );
use VegGuide::Util qw( string_is_empty );
use VegGuide::Web::CSS;
use VegGuide::Web::Javascript;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub begin : Private {
    my $self = shift;
    my $c    = shift;

    $ENV{SERVER_PORT} = $c->engine()->env()->{SERVER_PORT}
        if $c->engine()->env()
        && $c->engine()->env()->{SERVER_PORT} != 80;

    $ENV{SERVER_SCHEME} = $c->engine()->env()->{'psgi.url_scheme'};

    $self->_redirect_on_bad_uri($c);

    Alzabo::Runtime::UniqueRowCache->clear();
    VegGuide::AlzaboWrapper->ClearCache();
    VegGuide::PerRequestCache->ClearCache();

    # XXX - this is a hack to avoid checking in every call to ->ByID
    VegGuide::Location->_check_cache_time();

    return unless $c->request()->looks_like_browser();

    unless ( VegGuide::Config->IsProduction()
        || VegGuide::Config->Profiling() ) {
        VegGuide::Web::CSS->new()->create_single_file();
        VegGuide::Web::Javascript->new()->create_single_file();
    }

    my $response = $c->response();
    $response->breadcrumbs()->add(
        uri   => '/',
        label => 'Home',
    );

    for my $type ( 'RSS', 'Atom' ) {
        my $ct = 'application/' . lc $type . '+xml';

        $response->alternate_links()->add(
            mime_type => $ct,
            title     => "VegGuide.org: Sitewide Recent Changes",
            uri       => uri( path => '/site/recent.' . lc $type ),
        );
    }

    return 1;
}

sub end : Private {
    my $self = shift;
    my $c    = shift;

    return $self->next::method($c)
        if $c->stash()->{rest};

    if (   ( !$c->response()->status() || $c->response()->status() == 200 )
        && !$c->response()->body()
        && !@{ $c->error() || [] } ) {

        $c->response()->content_type( 'text/html; charset=UTF-8' )
            unless $c->response()->content_type();
        $c->forward( $c->view() );
    }

    return;
}

{
    my @broken_qs_keys = qw( _ action pag pa q ref );

    sub _redirect_on_bad_uri {
        my $self = shift;
        my $c    = shift;

        if ( $self->_is_hack_attempt($c) ) {
            $c->redirect_and_detach(
                site_uri( path => '/', with_host => 1 ) );
        }

        my $params = $c->request()->parameters();

        # GoogleBot is making request for URIs like
        # /region/362/filter?sort_order=ASC;page%3D2;order_by%3Dname;limit%3D20
        if ( any { /^(?:page|order_by|limit)=/ } keys %{$params} ) {
            for my $k ( keys %{$params} ) {
                if ( $k =~ /(\w+)=(.+)/ ) {
                    delete $params->{$k};
                    $params->{$1} = $2;
                }
            }

            $c->redirect_and_detach(
                site_uri(
                    path  => $c->request()->uri()->path(),
                    query => $params,
                )
            );
        }

        # Fixes requests for things like
        # http://www.vegguide.org/region/1454/filter?how_veg;limit=20
        if ( any { ! defined $params->{$_} } keys %{$params} ) {
            delete $params->{$_} for grep { ! defined $params->{$_} } keys %{$params};
            $c->redirect_and_detach(
                site_uri(
                    path  => $c->request()->uri()->path(),
                    query => $params,
                )
            );
        }

        if ( any { exists $params->{$_} } @broken_qs_keys ) {
            my $uri = $c->request()->uri();
            $uri->query_param_delete($_) for @broken_qs_keys;

            $c->redirect_and_detach($uri);
        }
    }
}

sub _is_hack_attempt {
    my $self = shift;
    my $c    = shift;

    my $params = $c->request()->parameters();

    return 1 if grep { /(?:DECLARE|SET) \@S/ } keys %{$params};
    return 1 if exists $params->{iframe};

    return 0;
}

sub _require_auth {
    my $self = shift;
    my $c    = shift;
    my $msg  = shift;

    return if $c->vg_user()->is_logged_in();

    $c->_redirect_with_error(
        error  => $msg,
        uri    => '/user/login_form',
        params => { return_to => $c->request()->uri() },
    );
}

sub _params_from_path_query {
    my $self = shift;
    my $path = shift;

    return if string_is_empty($path);

    my %p;
    for my $kv ( split /;/, $path ) {
        my ( $k, $v ) = map { uri_unescape($_) } split /=/, $kv;

        if ( $p{$k} ) {
            if ( ref $p{$k} ) {
                push @{ $p{$k} }, $v;
            }
            else {
                $p{$k} = [ $p{$k}, $v ];
            }
        }
        else {
            $p{$k} = $v;
        }
    }

    return %p;
}

{
    my %ContentTypes = map {
              $_ => 'application/vnd.vegguide.org-'
            . $_
            . '+json; charset=UTF-8; version='
            . $VegGuide::REST_VERSION
        } qw(
        entry
        entries
        entry-images
        entry-reviews
        region
        regions
        reviews
        root-regions
        search
        user
        users
    );

    sub _rest_response {
        my $self   = shift;
        my $c      = shift;
        my $type   = shift;
        my $entity = shift;
        my $status = shift // 'ok';

        die "Unknown type ($type)" unless $ContentTypes{$type};

        $c->response()->content_type( $ContentTypes{$type} );
        $c->response()->header( 'Access-Control-Allow-Origin' => '*' );

        my $meth = 'status_' . $status;
        $self->$meth(
            $c,
            entity => $entity,
        );

        $c->detach();

        return;
    }
}

{
    my $type
        = 'application/vnd.vegguide.org-error+json; charset=UTF-8; version=0.0.1';

    sub _rest_error_response {
        my $self    = shift;
        my $c       = shift;
        my $message = shift;
        my $status  = shift;

        my $meth = 'status_' . $status;

        $self->$meth(
            $c,
            message => $message,
        );

        $c->detach();

        return;
    }
}

sub _set_entity {
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;

    $c->response()->body( VegGuide::JSON->Encode($entity) );

    return 1;
}

__PACKAGE__->meta()->make_immutable();

1;
