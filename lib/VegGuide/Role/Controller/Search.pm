package VegGuide::Role::Controller::Search;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( all any );
use Scalar::Util qw( looks_like_number );
use URI::FromHash qw( uri );
use URI::QueryParam;

use Moose::Role;

sub _set_search_in_stash {
    my $self   = shift;
    my $c      = shift;
    my %config = @_;

    my $path = $config{path_query};
    $path ||= $c->request()->captures()->[ $config{captured_path_position} ]
        if exists $config{captured_path_position};

    my $search = $self->_search_from_request(
        $c,
        $path,
        $config{search_class},
        { $self->_extra_search_params( $c, $config{extra_params} ) },
    );

    return
        unless $self->_set_search_cursor_params(
        $c,
        $search,
        $config{defaults},
        );

    my $stash = $c->stash();

    $stash->{search} = $search;
    $stash->{pager}  = $search->pager();

    return;
}

sub _set_map_search_in_stash {
    my $self   = shift;
    my $c      = shift;
    my %config = @_;

    my %extra = $self->_extra_search_params( $c, $config{extra_params} );
    $extra{mappable_only} = 1;

    my $path = $config{path_query};
    $path ||= $c->request()->captures()->[ $config{captured_path_position} ]
        if exists $config{captured_path_position};

    my $search = $self->_search_from_request(
        $c,
        $path,
        $config{search_class},
        \%extra,
    );

    $search->set_cursor_params(
        order_by   => 'name',
        sort_order => 'ASC',
        page       => 1,
        limit      => 0,
    );

    my $stash = $c->stash();

    $stash->{search} = $search;

    return;
}

sub _set_printable_search_in_stash {
    my $self   = shift;
    my $c      = shift;
    my %config = @_;

    my $path = $config{path_query};
    $path ||= $c->request()->captures()->[ $config{captured_path_position} ]
        if exists $config{captured_path_position};

    my $search = $self->_search_from_request(
        $c, $path,
        $config{search_class}, {
            $self->_extra_search_params( $c, $config{extra_params} ),
            allow_closed => 0,
        },
    );

    $search->set_cursor_params(
        order_by   => 'name',
        sort_order => 'ASC',
        page       => 1,
        limit      => 0,
    );

    my $stash = $c->stash();

    $stash->{search} = $search;

    return;
}

sub _extra_search_params {
    my $self  = shift;
    my $c     = shift;
    my $extra = shift;

    return unless $extra;

    return $extra->($c);
}

my %paging_keys = map { $_ => 1 } qw(
    order_by
    sort_order
    page
    limit
);

my %address_keys = map { $_ => 1 } qw(
    address
    distance
    unit
);

sub _search_from_request {
    my $self  = shift;
    my $c     = shift;
    my $path  = shift;
    my $class = shift;
    my $extra = shift;

    my %path_params    = $self->_params_from_path_query($path);
    my %request_params = %{ $c->request()->parameters() };

    my %p = (
        %path_params,
        %request_params,
        %{ $extra || {} },
    );

    $self->_redirect_on_bad_request( $c, $class, %p );

    my %good_keys = (
        %paging_keys,
        %address_keys,
        map { $_ => 1 } $class->SearchKeys(),
    );

    if ( any { !$good_keys{$_} } keys %path_params ) {
        $c->redirect_and_detach( uri( path => '/' ), 301 );
    }

    if ( any { !$good_keys{$_} } keys %request_params ) {
        $c->redirect_and_detach( uri( path => '/' ), 301 );
    }

    delete $p{$_} for grep { /^possible/ } keys %p;
    delete @p{qw( order_by sort_order page limit )};
    delete $p{'ie-hack'};

    # used for forcing a JSON response
    delete $p{'content-type'};

    return $class->new(%p);
}

sub _redirect_on_bad_request {
    my $self  = shift;
    my $c     = shift;
    my $class = shift;
    my %p     = @_;

    if ( $p{sort} || $p{q} || $p{url} ) {

        # Noise from COK Veg* redirects
        my $uri = $c->request()->uri();
        $uri->query_param_delete($_) for $uri->query_param();
        $c->redirect_and_detach( $uri, 301 );
    }

    if ( exists $p{fb_xd_fragment} ) {
        my $uri = $c->request()->uri();
        $uri->query_param_delete('fb_xd_fragment');
        $c->redirect_and_detach( $uri, 301 );
    }

    if ( $p{limit} && $p{limit} !~ /^[0-9]+$/ ) {
        $c->redirect_and_detach( q{/}, 301 );
    }

    # Some l33t hacker bot keeps trying to stick links in these
    # parameters
    if ( grep { defined && /^http/ }
        @p{ 'order_by', 'sort_order', 'page', 'limit' } ) {

        $c->redirect_and_detach( q{/}, 301 );
    }

    # More l33t hackers
    if ( grep { /\.\./ || /_ult/ } keys %p ) {
        $c->redirect_and_detach( q{/}, 301 );
    }

    if ( $class =~ /ByLatLong/ && !all { defined $_ && looks_like_number($_) }
        @p{ 'latitude', 'longitude' } ) {

        $c->redirect_and_detach( q{/}, 301 );
    }

    my @bad_keys = qw( location_id new_query amp from );

    # Some bad redirects pointed bots to these URIs and now they keep
    # trying them -
    # /region/706?page=1&sort_order=DESC&order_by=Rating&location_id=706
    # and some are still including new_query=1
    #
    # weather.com generates links with from=search_webresults<1> in the query
    # string (wtf)
    if ( grep { exists $p{$_} } @bad_keys ) {
        my $p = $c->request()->parameters();

        delete @{$p}{@bad_keys};

        my $path = uri(
            path  => '/' . $c->request()->path(),
            query => $p,
        );

        $c->redirect_and_detach( $path, 301 );
    }
}

sub _set_search_cursor_params {
    my $self     = shift;
    my $c        = shift;
    my $search   = shift;
    my $defaults = shift || {};

    my $params = $c->request()->parameters();

    my $page = $params->{page} || 1;
    if ( $page =~ /\D/ ) {
        $c->redirect_and_detach( $search->uri(1) );
    }

    my $limit = $params->{limit} || $c->vg_user()->entries_per_page();

    $limit = 20 unless looks_like_number($limit);
    $limit = 100 if $limit > 100;

    my %p = (
        page  => $page,
        limit => $limit,
    );

    if ( $defaults->{order_by} ) {
        $p{order_by}   = $defaults->{order_by};
        $p{sort_order} = $defaults->{sort_order};
    }

    for my $k (qw( order_by sort_order )) {
        $p{$k} = $params->{$k}
            if defined $params->{$k};
    }

    $search->set_cursor_params(%p);

    if ( ( $page - 1 ) * $limit > $search->count() ) {
        $c->redirect_and_detach( $search->uri(1) );
    }

    return 1;
}

sub _search_post {
    my $self   = shift;
    my $c      = shift;
    my $is_map = shift;

    my $meth = $is_map ? '_set_map_search_in_stash' : '_set_search_in_stash';

    $self->$meth( $c, @_ );

    my $search = $c->stash()->{search};

    return unless $search;

    my $uri_meth = $is_map ? 'map_uri' : 'uri';

    $c->response()->redirect( $search->$uri_meth() );
}

1;
