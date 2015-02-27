package VegGuide::Controller::Region;

use strict;
use warnings;
use namespace::autoclean;

use Scalar::Util qw( blessed );
use URI::FromHash qw( uri );
use VegGuide::Config;
use VegGuide::Location;
use VegGuide::Pageset;
use VegGuide::RSSWriter;
use VegGuide::Search::Vendor::ByLocation;
use VegGuide::SiteURI qw( entry_uri region_uri site_uri );
use VegGuide::Util qw( string_is_empty );
use VegGuide::Vendor;

use Moose;

BEGIN { extends 'VegGuide::Controller::Base'; }

with 'VegGuide::Role::Controller::Comment',
    'VegGuide::Role::Controller::Feed',
    'VegGuide::Role::Controller::Search';

sub _set_location : Chained('/') : PathPart('region') : CaptureArgs(1) {
    my $self        = shift;
    my $c           = shift;
    my $location_id = shift;

    $c->redirect_and_detach('/')
        unless $location_id && $location_id =~ /^[0-9]+$/;

    my $location = VegGuide::Location->new( location_id => $location_id );

    $c->redirect_and_detach('/')
        unless $location;

    $c->stash()->{location} = $location;

    return
        unless $c->request()->looks_like_browser()
            && $c->request()->method() eq 'GET';

    for my $type ( 'RSS', 'Atom' ) {
        my $ct = 'application/' . lc $type . '+xml';

        $c->response()->alternate_links()->add(
            mime_type => $ct,
            title => 'VegGuide.org: Recent Changes for ' . $location->name(),
            uri   => region_uri(
                location => $location,
                path     => 'recent.' . lc $type,
            ),
        );
    }

    $c->response()->breadcrumbs()->add_region_breadcrumbs($location);

    $c->add_tab(
        {
            uri   => region_uri( location => $location ),
            label => 'Entries/Regions',
            tooltip => 'Entries and regions in ' . $location->name(),
            id      => 'entries',
        }
    );

    if ( $location->vendor_count() ) {
        $c->add_tab(
            {
                uri   => region_uri( location => $location, path => 'map' ),
                label => 'Map',
                tooltip => 'Map of ' . $location->name(),
                id      => 'map',
            }
        );

        $c->add_tab(
            {
                uri =>
                    region_uri( location => $location, path => 'printable' ),
                label   => 'Printable',
                tooltip => 'Printable entry list for ' . $location->name(),
                id      => 'printable',
            }
        );

        $c->add_tab(
            {
                uri   => region_uri( location => $location, path => 'stats' ),
                label => 'Stats',
                tooltip => 'Stats for ' . $location->name(),
                id      => 'stats',
            }
        );
    }

    $c->add_tab(
        {
            uri   => region_uri( location => $location, path => 'feeds' ),
            label => 'Feeds',
            tooltip => 'Atom & RSS feeds for ' . $location->name(),
            id      => 'feeds',
        }
    );
}

{
    my %SearchConfig = (
        search_class => 'VegGuide::Search::Vendor::ByLocation',
        extra_params => sub { ( location => $_[0]->stash()->{location} ) },
        defaults     => {
            order_by   => 'rating',
            sort_order => 'desc',
        },
    );

    sub region : Chained('_set_location') : PathPart('') : Args(0) :
        ActionClass('+VegGuide::Action::REST') {
    }

    sub region_GET : Private {
        my $self = shift;
        my $c    = shift;

        $self->_rest_response(
            $c,
            'region',
            $c->stash()->{location}->rest_data(),
        );

        return;
    }

    sub region_GET_html : Private {
        my $self = shift;
        my $c    = shift;

        $self->_set_search_in_stash( $c, %SearchConfig );

        $c->tab_by_id('entries')->set_is_selected(1);

        $self->_set_uris_for_search($c);

        $c->stash()->{template} = '/region/view';
    }

    # This would not be necessary if chained actions could have a
    # variable number of Args.
    sub empty_filter : Chained('_set_location') : PathPart('filter') : Args(0)
    {
        my $self = shift;
        my $c    = shift;

        $c->tab_by_id('entries')->set_is_selected(1)
            if $c->request()->looks_like_browser()
                && $c->request()->method() eq 'GET';

        $c->detach('filter');
    }

    sub entries : Chained('_set_location') : PathPart('entries') : Args(0)
        ActionClass('+VegGuide::Action::REST') {
    }

    sub entries_GET {
        my $self = shift;
        my $c    = shift;

        # The printable search doesn't do paging - it also doesn't include
        # entries mark closed.
        $self->_set_printable_search_in_stash(
            $c,
            %SearchConfig,
        );

        return unless $c->stash()->{search};

        my @entries;

        my $vendors = $c->stash()->{search}->vendors();
        while ( my $vendor = $vendors->next() ) {
            push @entries, $vendor->rest_data( include_related => 0 );
        }

        $self->_rest_response(
            $c,
            'entries',
            \@entries,
        );

        return;
    }

    sub filter : Chained('_set_location') : PathPart('filter') : Args(1) :
        ActionClass('+VegGuide::Action::REST') {
    }

    sub filter_GET_html : Private {
        my $self = shift;
        my $c    = shift;
        my $path = shift;

        $self->_set_search_in_stash( $c, %SearchConfig, path_query => $path );

        return unless $c->stash()->{search};

        $c->tab_by_id('entries')->set_is_selected(1)
            if $c->request()->looks_like_browser()
                && $c->request()->method() eq 'GET';

        $self->_set_uris_for_search($c);

        $c->stash()->{template} = '/region/view';
    }

    sub filter_POST : Private {
        my $self = shift;
        my $c    = shift;
        my $path = shift;

        return $self->_search_post( $c, 0, %SearchConfig,
            path_query => $path );
    }

    sub map_unfiltered : Chained('_set_location') : PathPart('map') : Args(0)
    {
        my $self = shift;
        my $c    = shift;

        $c->tab_by_id('map')->set_is_selected(1)
            if $c->tab_by_id('map')
                && $c->request()->looks_like_browser()
                && $c->request()->method() eq 'GET';

        $self->_set_uris_for_search($c);

        $c->detach('map');
    }

    sub map : Chained('_set_location') : PathPart('map') : Args(1) :
        ActionClass('+VegGuide::Action::REST') {
    }

    sub map_GET_html : Private {
        my $self = shift;
        my $c    = shift;
        my $path = shift;

        $self->_set_map_search_in_stash( $c, %SearchConfig,
            path_query => $path );

        return unless $c->stash()->{search};

        $c->tab_by_id('map')->set_is_selected(1)
            if $c->tab_by_id('map')
                && $c->request()->looks_like_browser()
                && $c->request()->method() eq 'GET';

        $self->_set_uris_for_search($c);

        $c->stash()->{template} = '/region/map';
    }

    sub map_POST : Private {
        my $self = shift;
        my $c    = shift;
        my $path = shift;

        return $self->_search_post( $c, 'is map', %SearchConfig,
            path_query => $path );
    }

    sub printable_unfiltered : Chained('_set_location') :
        PathPart('printable') : Args(0) {
        my $self = shift;
        my $c    = shift;

        $c->tab_by_id('printable')->set_is_selected(1)
            if $c->tab_by_id('printable')
                && $c->request()->looks_like_browser()
                && $c->request()->method() eq 'GET';

        $self->_set_uris_for_search($c);

        $c->detach('printable');
    }

    sub printable : Chained('_set_location') : PathPart('printable') : Args(1)
    {
        my $self = shift;
        my $c    = shift;
        my $path = shift;

        $self->_set_printable_search_in_stash( $c, %SearchConfig,
            path_query => $path );

        return unless $c->stash()->{search};

        $c->tab_by_id('printable')->set_is_selected(1)
            if $c->tab_by_id('printable')
                && $c->request()->looks_like_browser()
                && $c->request()->method() eq 'GET';

        $self->_set_uris_for_search($c);

        $c->stash()->{template} = '/shared/printable-entry-list';
    }

    sub _set_uris_for_search {
        my $self = shift;
        my $c    = shift;

        my $search = $c->stash()->{search};

        return unless $search;

        return unless $c->tab_by_id('map');

        $c->tab_by_id('entries')->set_uri( $search->uri() );
        $c->tab_by_id('map')->set_uri( $search->map_uri() );
        $c->tab_by_id('printable')->set_uri( $search->printable_uri() );

        return;
    }
}

sub region_PUT : Private {
    my $self = shift;
    my $c    = shift;

    my $location = $c->stash()->{location};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_edit_location($location);

    my %data = $c->request()->location_data();

    delete $data{skip_duplicate_check};

    $location->update(%data);

    if ( $c->vg_user()->is_admin() ) {
        for my $user ( map { VegGuide::User->new( user_id => $_ ) }
            $c->request()->param('remove-maintainer') ) {
            $location->remove_owner($user);
        }

        for my $user ( map { VegGuide::User->new( user_id => $_ ) }
            $c->request()->param('user_id') ) {
            $location->add_owner($user);
        }
    }

    $c->add_message( $location->name() . ' has been updated.' );

    $c->redirect_and_detach( region_uri( location => $location ) );
}

sub region_POST : Private {
    my $self = shift;
    my $c    = shift;

    $c->redirect_and_detach('/')
        unless $c->stash()->{location};

    return $self->_new_entry_submit($c);
}

sub region_confirm_deletion : Chained('_set_location') :
    PathPart('deletion_confirmation_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $location = $c->stash()->{location};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_location($location);

    $c->stash()->{thing} = 'region';
    $c->stash()->{name}  = $location->name();

    $c->stash()->{uri} = region_uri( location => $location );

    $c->stash()->{template} = '/shared/deletion-confirmation-form';
}

sub region_DELETE : Private {
    my $self = shift;
    my $c    = shift;

    my $location = $c->stash()->{location};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_location($location);

    my $name   = $location->name();
    my $parent = $location->parent();

    $location->delete();

    $c->add_message("$name has been deleted.");

    my $redirect = $parent ? region_uri( location => $parent ) : '/';
    $c->redirect_and_detach($redirect);
}

sub _new_entry_submit {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to submit a new entry. If you don't have an account you can create one now.},
    );

    my $location = $c->stash()->{location};

    unless ( $c->vg_user()->is_admin() || $location->can_have_vendors() ) {
        $c->add_message('This region cannot have entries.');
        $c->redirect_and_detach( region_uri( location => $location ) );
    }

    my %data = $c->request()->vendor_data();

    my $vendor;
    eval {
        $vendor = VegGuide::Vendor->create(
            %data,
            user_id     => $c->vg_user()->user_id(),
            location_id => $location->location_id(),
        );
    };

    if ( my $e = $@ ) {
        $c->_redirect_with_error(
            error => $e,
            uri => region_uri( location => $location, path => 'entry_form' ),
            params => \%data,
        );
    }

    $c->add_message( $vendor->name() . ' has been added.' );

    if ( $location->has_hours() ) {
        $c->redirect_and_detach(
            entry_uri( vendor => $vendor, path => 'edit_hours_form' ) );
    }
    else {
        $c->redirect_and_detach( region_uri( location => $location ) );
    }
}

sub entry_form : Chained('_set_location') : PathPart('entry_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to submit a new entry. If you don't have an account you can create one now.},
    );

    my $location = $c->stash()->{location};

    unless ( $c->vg_user()->is_admin() || $location->can_have_vendors() ) {
        $c->add_message('This region cannot have entries.');
        $c->redirect_and_detach( region_uri( location => $location ) );
    }

    my $cloned_vendor_id = $c->request()->param('cloned_vendor_id');
    $c->stash()->{cloned_vendor}
        = VegGuide::Vendor->new( vendor_id => $cloned_vendor_id )
        if $cloned_vendor_id;

    $c->stash()->{template} = '/region/entry-form';
}

# This happens when the clone "pick a location" form is submitted.
sub entry_form_no_region : LocalRegex('^entry_form$') {
    my $self = shift;
    my $c    = shift;

    my $location_id = $c->request()->param('location_id') || 0;

    my $location = VegGuide::Location->new( location_id => $location_id );

    unless ($location) {
        $c->_redirect_with_error(
            error => 'You must pick a region for this new entry.',
            uri   => uri(
                path => '/site/clone_entry_form',
                query =>
                    { vendor_id => $c->request()->param('cloned_vendor_id') },
            ),
        );
    }

    my $uri = region_uri(
        location => $location,
        path     => 'entry_form',
        query =>
            { cloned_vendor_id => $c->request()->param('cloned_vendor_id') },
    );

    $c->redirect_and_detach($uri);
}

sub comment_form : Chained('_set_location') : PathPart('comment_form') :
    Args(1) {
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to write a comment. If you don't have an account you can create one now.},
    );

    my $user = VegGuide::User->new( user_id => $user_id );
    my $comment = $c->stash()->{location}->comment_by_user($user);

    $c->redirect_and_detach('/')
        unless $user && $comment;

    $c->_redirect_with_error(
        error => 'You do not have permission to edit this comment.',
        uri   => '/',
    ) unless $c->vg_user()->can_edit_comment($comment);

    $c->stash()->{comment}  = $comment;
    $c->stash()->{template} = '/region/comment-form';
}

sub new_comment_form : Chained('_set_location') : PathPart('comment_form') :
    Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to write a comment. If you don't have an account you can create one now.},
    );

    $c->stash()->{comment} = VegGuide::LocationComment->potential();

    $c->stash->{template} = '/region/comment-form';
}

sub new_region_comment : Chained('_set_location') : PathPart('comment') :
    Args(0) : ActionClass('+VegGuide::Action::REST') {
}

sub new_region_comment_POST : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to write a comment. If you don't have an account you can create one now.},
    );

    my $location = $c->stash()->{location};

    my $comment = $self->_comment_post(
        $c, $location,
        region_uri( location => $location, path => 'comment_form' ),
    );

    if ( $c->vg_user()->user_id() == $comment->user_id() ) {
        $c->add_message(
            'Thanks for your comment on ' . $location->name() . '.' );
    }
    else {
        $c->add_message('The comment has been updated.');
    }

    $c->redirect_and_detach( region_uri( location => $location ) );
}

sub _set_comment : Chained('_set_location') : PathPart('comment') : CaptureArgs(1) {
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    my $location = $c->stash()->{location};

    my $user = VegGuide::User->new( user_id => $user_id );
    my $comment = $location->comment_by_user($user);

    $c->redirect_and_detach('/')
        unless $comment;

    $c->stash()->{comment} = $comment;
}

sub confirm_deletion : Chained('_set_comment') :
    PathPart('deletion_confirmation_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to delete a comment. If you don't have an account you can create one now.},
    );

    my $comment = $c->stash()->{comment};

    my $subject
        = $comment->user_id() == $c->vg_user()->user_id()
        ? 'your comment'
        : 'the comment you specified';

    $c->stash()->{thing} = 'region comment';
    $c->stash()->{name}  = $subject;

    $c->stash()->{uri} = region_uri(
        location => $comment->location(),
        path     => 'comment/' . $comment->user_id()
    );

    $c->stash()->{template} = '/shared/deletion-confirmation-form';
}

sub region_comment : Chained('_set_comment') : PathPart('') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub region_comment_DELETE : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to delete a comment. If you don't have an account you can create one now.},
    );

    my $comment = $c->stash()->{comment};

    $c->redirect_and_detach('/')
        unless $comment;

    $c->_redirect_with_error(
        error => 'You do not have permission to delete this comment.',
        uri   => '/',
    ) unless $c->vg_user()->can_delete_comment($comment);

    my $subject
        = $comment->user_id() == $c->vg_user()->user_id()
        ? 'Your comment'
        : 'The comment you specified';

    my $location = $comment->location();

    $comment->delete();

    $c->add_message("$subject has been deleted.");

    $c->redirect_and_detach( region_uri( location => $location ) );
}

sub stats : Chained('_set_location') : PathPart('stats') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('stats')->set_is_selected(1)
        if $c->tab_by_id('stats');

    $c->stash()->{template} = '/region/stats';
}

sub feeds : Chained('_set_location') : PathPart('feeds') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('feeds')->set_is_selected(1)
        if $c->tab_by_id('feeds');

    $c->stash()->{template} = '/region/feeds';
}

sub recent_rss : Chained('_set_location') : PathPart('recent.rss') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_recent_feed( $c, 'rss' );
}

sub recent_atom : Chained('_set_location') : PathPart('recent.atom') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_recent_feed( $c, 'atom' );
}

sub _recent_feed {
    my $self = shift;
    my $c    = shift;
    my $type = shift;

    my $method
        = $c->request()->param('reviews_only') ? 'new_reviews_feed'
        : $c->request()->param('entries_only') ? 'new_vendors_feed'
        :   'new_vendors_and_reviews_feed';

    my $feed = $c->stash()->{location}->$method();

    $self->_serve_feed( $c, $feed, $type );
}

sub data_feed : Chained('_set_location') : PathPart('data.rss') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $location = $c->stash()->{location};

    my $cache_only = $location->descendants_vendor_count()
        > VegGuide::Location->DataFeedDynamicLimit() ? 1 : 0;

    $self->_serve_rss_data_file(
        $c,
        $location->data_feed_rss_file( cache_only => $cache_only )
    );
}

sub search : Local : ActionClass('+VegGuide::Action::REST') {
}

sub search_GET {
    my $self = shift;
    my $c    = shift;

    my $name = $c->request()->param('name') || '';

    my $locations = VegGuide::Location->ByNameOrCityName( name => $name );

    my @locations;
    while ( my $loc = $locations->next() ) {
        my $rest_data = $loc->rest_data();

        unless ( $loc->name_matches_text($name) ) {
            my @cities = $loc->cities_matching_text($name);
            $rest_data->{cities} = \@cities;
        }

        push @locations, $rest_data;
    }

    return $self->status_ok(
        $c,
        entity => \@locations,
    );
}

sub edit_form : Chained('_set_location') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_edit_location( $c->stash()->{location} );

    $c->stash()->{template} = '/region/edit-form';
}

sub new_region_form : Chained('_set_location') : PathPart('new_region_form') :
    Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to add a new region. If you don't have an account you can create one now.},
    );

    $c->stash()->{template} = '/region/new-region-form';
}

sub regions : Path('') : ActionClass('+VegGuide::Action::REST') {
}

sub regions_POST {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to add a new region. If you don't have an account you can create one now.},
    );

    my %data = $c->request()->location_data();
    $data{parent_location_id} = $c->request()->param('parent_location_id');

    delete @data{
        qw( localized_name time_zone_name can_have_vendors locale_id )}
        unless $c->vg_user()->is_admin();

    unless ( string_is_empty( $data{name} ) ) {
        $data{name} =~ s/^\s+|\s+$//g;

        unless ( delete $data{skip_duplicate_check} ) {
            my @locations
                = VegGuide::Location->ByNameOrCityName( name => $data{name} )
                ->all();

            $c->redirect_and_detach(
                uri(
                    path  => '/site/duplicate_resolution_form',
                    query => \%data,
                )
            ) if @locations;
        }
    }

    my @errors;
    push @errors, 'You must provide a parent region.'
        unless $data{parent_location_id} || $c->vg_user()->is_admin();

    delete $data{parent_location_id} unless defined $data{parent_location_id};

    my $location;
    eval {
        $location = VegGuide::Location->create(
            %data,
            user_id => $c->vg_user()->user_id()
        );
    };

    if ( my $e = $@ ) {
        die $e unless blessed $e && $e->can('errors');

        push @errors, @{ $e->errors() };
    }

    if (@errors) {
        my $parent = VegGuide::Location->new(
            location_id => $data{parent_location_id} );

        my $uri
            = $parent
            ? region_uri( location => $parent, path => 'new_region_form' )
            : '/region/new_region_form';

        $c->_redirect_with_error(
            error  => \@errors,
            uri    => $uri,
            params => $c->request()->params(),
        );
    }

    my $msg = 'Added a new region, ' . $location->name();
    $msg .= ' in ' . $location->parent()->name()
        if $location->parent();
    $msg .= q{.};

    $c->add_message($msg);

    $c->redirect_and_detach( region_uri( location => $location ) );
}

sub recent : Local {
    my $self = shift;
    my $c    = shift;

    my $days = $c->request()->param('days') || 7;

    $c->stash()->{days} = $days;

    $c->stash()->{locations}
        = VegGuide::Location->RecentlyAdded( days => $days );

    $c->stash()->{template} = '/site/recent-region-list';
}

sub comment : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{comments} = VegGuide::Location->AllComments();

    $c->stash()->{template} = '/site/comment-list';
}

sub maintainers : Local {
    my $self = shift;
    my $c    = shift;

    $c->redirect_and_detach('/')
        unless $c->vg_user()->is_admin();

    $c->stash()->{users} = VegGuide::User->RegionMaintainers();

    $c->stash()->{template} = '/site/admin/region-maintainer-list';
}

__PACKAGE__->meta()->make_immutable();

1;
