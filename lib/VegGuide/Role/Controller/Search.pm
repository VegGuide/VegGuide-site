package VegGuide::Role::Controller::Search;

use strict;
use warnings;

use Class::Trait 'base';

use Scalar::Util qw( looks_like_number );
use URI::FromHash qw( uri );


sub _set_search_in_stash
{
    my $self   = shift;
    my $c      = shift;
    my %config = @_;

    my $path = $config{path_query};
    $path ||= $c->request()->captures()->[ $config{captured_path_position} ]
        if exists $config{captured_path_position};

    my $search =
        $self->_search_from_request
            ( $c,
              $path,
              $config{search_class},
              { $self->_extra_search_params( $c, $config{extra_params} ) },
            );

    return unless $self->_set_search_cursor_params( $c, $search );

    my $stash = $c->stash();

    $stash->{search} = $search;
    $stash->{pager}  = $search->pager();

    return;
}

sub _set_map_search_in_stash
{
    my $self   = shift;
    my $c      = shift;
    my %config = @_;

    my %extra = $self->_extra_search_params( $c, $config{extra_params} );
    $extra{mappable_only} = 1;

    my $path = $config{path_query};
    $path ||= $c->request()->captures()->[ $config{captured_path_position} ]
        if exists $config{captured_path_position};

    my $search =
        $self->_search_from_request
            ( $c,
              $path,
              $config{search_class},
              \%extra,
            );

    $search->set_cursor_params( order_by   => 'name',
                                sort_order => 'ASC',
                                page       => 1,
                                limit      => 0,
                              );

    my $stash = $c->stash();

    $stash->{search} = $search;

    return;
}

sub _set_printable_search_in_stash
{
    my $self   = shift;
    my $c      = shift;
    my %config = @_;

    my $path = $config{path_query};
    $path ||= $c->request()->captures()->[ $config{captured_path_position} ]
        if exists $config{captured_path_position};

    my $search =
        $self->_search_from_request
            ( $c,
              $path,
              $config{search_class},
              { $self->_extra_search_params( $c, $config{extra_params} ) },
            );

    $search->set_cursor_params( order_by   => 'name',
                                sort_order => 'ASC',
                                page       => 1,
                                limit      => 0,
                              );

    my $stash = $c->stash();

    $stash->{search} = $search;

    return;
}

sub _extra_search_params
{
    my $self  = shift;
    my $c     = shift;
    my $extra = shift;

    return unless $extra;

    return $extra->($c);
}

sub _search_from_request
{
    my $self  = shift;
    my $c     = shift;
    my $path  = shift;
    my $class = shift;
    my $extra = shift;

    my %p = ( $self->_params_from_path_query($path),
              %{ $c->request()->parameters() },
              %{ $extra || {} },
            );

    $self->_redirect_on_bad_request( $c, %p );

    delete $p{$_} for grep { /^possible/ } keys %p;
    delete @p{ qw( order_by sort_order page limit ) };
    delete $p{'ie-hack'};

    return $class->new(%p);
}

sub _redirect_on_bad_request
{
    my $self = shift;
    my $c    = shift;
    my %p    = @_;

    # Some l33t hacker bot keeps trying to stick links in these
    # parameters
    if ( grep { defined && /^http/ } @p{ 'order_by', 'sort_order', 'page', 'limit' } )
    {
        $c->redirect_and_detach( q{/}, 301 );
    }

    my @bad_keys = qw( location_id new_query amp );
    # Some bad redirects pointed bots to these URIs and now they keep
    # trying them -
    # /region/706?page=1&sort_order=DESC&order_by=Rating&location_id=706
    # and some are still including new_query=1
    if ( grep { exists $p{$_} } @bad_keys )
    {
        my $p = $c->request()->parameters();

        delete @{ $p }{ @bad_keys };

        my $path = uri( path  => '/' . $c->request()->path(),
                        query => $p,
                      );

        $c->redirect_and_detach( $path, 301 );
    }
}

sub _set_search_cursor_params
{
    my $self   = shift;
    my $c      = shift;
    my $search = shift;

    my $params = $c->request()->parameters();

    my $page = $params->{page} || 1;

    my $limit = $params->{limit} || $c->vg_user()->entries_per_page();

    $limit = 20 unless looks_like_number($limit);
    $limit = 100 if $limit > 100;

    my %p = ( page  => $page,
              limit => $limit,
            );

    for my $k ( qw( order_by sort_order ) )
    {
        $p{$k} = $params->{$k}
            if defined $params->{$k};
    }

    $search->set_cursor_params(%p);

    if ( ( $page - 1 ) * $limit > $search->count() )
    {
        $c->redirect_and_detach( $search->uri(1) );
    }

    return 1;
}

sub _search_post
{
    my $self   = shift;
    my $c      = shift;
    my $is_map = shift;

    my $meth = $is_map ? '_set_map_search_in_stash' : '_set_search_in_stash';

    $self->$meth( $c, @_ );

    my $search = $c->stash()->{search};

    return unless $search;

    my $uri_meth = $is_map ? 'map_uri' : 'uri';

    if ( $c->request()->looks_like_browser() )
    {
        $c->response()->redirect( $search->$uri_meth() );
    }
    else
    {
        $self->_return_data_for_ajax_filter( $c, $search, $uri_meth );
    }
}

sub _return_data_for_ajax_filter
{
    my $self     = shift;
    my $c        = shift;
    my $search   = shift;
    my $uri_meth = shift;

    my @filters;
    for my $filter ( $search->filter_names() )
    {
        my $clone = $search->clone();
        $clone->delete($filter);

        push @filters, { description => $search->filter_description($filter),
                         delete_uri  => $clone->$uri_meth(),
                       };
    }

    $search->set_cursor_params( order_by   => 'name',
                                sort_order => 'ASC',
                                page       => 1,
                                limit      => $c->vg_user()->entries_per_page(),
                              );

    my %response;
    %response =
        ( uri     => $search->$uri_meth(),
          filters => \@filters,
          count   => $search->count(),
        );

    return
        $self->status_created( $c,
                               location => $search->$uri_meth(),
                               entity   => \%response,
                             );
}


1;
