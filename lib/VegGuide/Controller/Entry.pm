package VegGuide::Controller::Entry;

use strict;
use warnings;
use namespace::autoclean;

use Lingua::EN::Inflect qw( PL );
use Scalar::Util qw( looks_like_number );
use Time::HiRes;
use URI::Escape qw( uri_unescape );
use VegGuide::Search::Vendor::All;
use VegGuide::Search::Vendor::ByLatLong;
use VegGuide::Search::Vendor::ByName;
use VegGuide::SiteURI qw( entry_uri entry_image_uri region_uri );
use VegGuide::Vendor;

use Moose;

BEGIN { extends 'VegGuide::Controller::Base'; }

with 'VegGuide::Role::Controller::Comment',
    'VegGuide::Role::Controller::Search';

sub list : Path('') {
    my $self = shift;
    my $c    = shift;

    my $search = VegGuide::Search::Vendor::All->new();

    my $params = $c->request()->parameters();
    my %p
        = map { $_ => $params->{$_} }
        grep { defined $params->{$_} } qw( order_by sort_order page limit );

    my $limit = $params->{limit} || $c->vg_user()->entries_per_page();

    $limit = 20 unless looks_like_number($limit);
    $limit = 100 if $limit > 100;

    $p{limit} = $limit;

    $search->set_cursor_params(%p);

    $c->stash()->{search} = $search;
    $c->stash()->{pager}  = $search->pager();

    $c->stash()->{template} = '/site/entry-list';
}

sub _set_vendor : Chained('/') : PathPart('entry') : CaptureArgs(1) {
    my $self      = shift;
    my $c         = shift;
    my $vendor_id = shift;

    my $vendor = VegGuide::Vendor->new( vendor_id => $vendor_id );

    $c->redirect_and_detach('/')
        unless $vendor;

    $c->stash()->{vendor} = $vendor;

    return
        unless $c->request()->looks_like_browser()
            && $c->request()->method() eq 'GET';

    my $location = $vendor->location();

    $c->add_tab(
        {
            uri     => entry_uri( vendor => $vendor ),
            label   => 'Info',
            tooltip => 'About ' . $vendor->name(),
            id      => 'info',
        }
    );

    $c->add_tab(
        {
            uri   => entry_uri( vendor => $vendor, path => 'reviews' ),
            label => 'Reviews',
            tooltip => 'Reviews and ratings for ' . $vendor->name(),
            id      => 'reviews',
        }
    );

    if ( $vendor->map_uri() ) {
        $c->add_tab(
            {
                uri   => entry_uri( vendor => $vendor, path => 'map' ),
                label => 'Map',
                tooltip => 'Map for ' . $vendor->name(),
                id      => 'map',
            }
        );
    }

    $c->response()->breadcrumbs()->add_region_breadcrumbs($location);

    $c->response()->breadcrumbs()->add(
        uri   => entry_uri( vendor => $vendor ),
        label => $vendor->name(),
    );
}

sub entry : Chained('_set_vendor') : PathPart('') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub entry_GET : Private {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};

    $self->_rest_response(
        $c,
        'entry',
        $vendor->rest_data(),
    );
}

sub entry_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('info')->set_is_selected(1);

    my $vendor = $c->stash()->{vendor};

    my $review_count = $vendor->review_count();

    my $comments;
    $comments = $vendor->comments( limit => 2 )
        if $review_count;

    $c->stash()->{comments} = $comments;

    $c->stash()->{template} = '/entry/view';
}

sub entry_PUT : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to edit an entry. If you don't have an account you can create one now.},
    );

    my $vendor = $c->stash()->{vendor};

    my %data = $c->request()->vendor_data();

    delete $data{location_id}
        unless $c->vg_user()->is_admin();

    my @msg;
    eval {
        if ( $c->vg_user()->can_edit_vendor($vendor) ) {
            $vendor->update( %data, user => $c->vg_user() );

            push @msg,
                'Changes to ' . $vendor->name() . ' have been recorded.';

            if ( $data{location_id} ) {
                push @msg,
                      $vendor->name()
                    . ' has been moved to '
                    . $vendor->location()->name() . q{.};
            }
        }
        elsif ( keys %data ) {
            $vendor->save_core_suggestion(
                suggestion => \%data,
                comment    => ( $c->request()->param('comment') || '' ),
                user_wants_notification =>
                    ( $c->request()->param('user_wants_notification') || 0 ),
                user => $c->vg_user(),
            );

            push @msg, 'Your suggestion has been saved.';
        }
    };

    if ( my $e = $@ ) {
        $c->_redirect_with_error(
            error  => $e,
            uri    => entry_uri( vendor => $vendor, path => 'edit_form' ),
            params => \%data,
        );
    }

    $c->add_message($_) for @msg;

    $c->redirect_and_detach( entry_uri( vendor => $vendor ) );
}

sub map : Chained('_set_vendor') : PathPart('map') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};
    unless ( $vendor->map_uri() ) {
        $c->redirect_and_detach( entry_uri( vendor => $vendor ) );
    }

    $c->tab_by_id('map')->set_is_selected(1)
        if $c->tab_by_id('map');

    $c->stash()->{template} = '/entry/large-map';
}

sub confirm_deletion : Chained('_set_vendor') :
    PathPart('deletion_confirmation_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_vendor($vendor);

    $c->stash()->{thing} = 'entry';
    $c->stash()->{name}  = $vendor->name();

    $c->stash()->{uri} = entry_uri( vendor => $vendor );

    $c->stash()->{template} = '/shared/deletion-confirmation-form';
}

sub entry_DELETE : Private {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_vendor($vendor);

    my $location = $vendor->location();
    my $name     = $vendor->name();

    $vendor->delete( calling_user => $c->vg_user() );

    $c->add_message("$name was deleted.");

    $c->redirect_and_detach( region_uri( location => $location ) );
}

sub rating : Chained('_set_vendor') : PathPart('rating') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

# This happens when a user clicks a rating star but is not
# logged-in. After login they end up being redirect to this URI.
sub rating_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    $c->redirect_and_detach( entry_uri( vendor => $c->stash()->{vendor} ) );
}

sub rating_POST : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to rate an entry. If you don't have an account you can create one now.},
    );

    my $vendor = $c->stash()->{vendor};

    $vendor->add_or_update_rating(
        user   => $c->vg_user(),
        rating => $c->request()->param('rating'),
    );

    if ( $c->request()->looks_like_browser() ) {
        $c->add_message(
            'Your rating for ' . $vendor->name() . ' has been recorded.' );
        $c->redirect_and_detach( entry_uri( vendor => $vendor ) );
    }
    else {
        my ( $weighted_average, $total_ratings )
            = $vendor->weighted_rating_and_count();

        my %rating_info = (
            weighted_average => $weighted_average,
            vote_count       => $total_ratings . q{ }
                . PL( 'vote', $total_ratings ),
        );

        $self->status_accepted(
            $c,
            entity => \%rating_info,
        );
    }
}

sub edit_form : Chained('_set_vendor') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to edit an entry. If you don't have an account you can create one now.},
    );

    $c->stash()->{template} = '/entry/edit-form';
}

sub closed_form : Chained('_set_vendor') : PathPart('closed_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to edit an entry. If you don't have an account you can create one now.},
    );

    $c->stash()->{template} = '/entry/closed-form';
}

sub review_form : Chained('_set_vendor') : PathPart('review_form') : Args(1) {
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to write a review. If you don't have an account you can create one now.},
    );

    my $user = VegGuide::User->new( user_id => $user_id );
    my $comment = $c->stash()->{vendor}->comment_by_user($user);

    $c->redirect_and_detach('/')
        unless $user && $comment;

    $c->_redirect_with_error(
        error => 'You do not have permission to edit this review.',
        uri   => '/',
    ) unless $c->vg_user()->can_edit_review($comment);

    $c->stash()->{comment} = $comment;

    $c->stash()->{template} = '/entry/review-form';
}

sub new_review_form : Chained('_set_vendor') : PathPart('review_form') :
    Args(0) {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};

    if ( my $comment = $vendor->comment_by_user( $c->vg_user() ) ) {
        $c->redirect_and_detach(
            entry_uri(
                vendor => $vendor,
                path   => 'review_form/' . $c->vg_user()->user_id()
            )
        );
    }

    $self->_require_auth(
        $c,
        q{You must be logged in to write a comment. If you don't have an account you can create one now.},
    );

    $c->stash()->{comment} = VegGuide::VendorComment->potential(
        vendor_id => $vendor->vendor_id(),
        user_id   => $c->vg_user()->user_id(),
    );

    $c->stash()->{template} = '/entry/review-form';
}

sub reviews : Chained('_set_vendor') : PathPart('reviews') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub reviews_GET : Private {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};

    $self->_rest_response(
        $c,
        'entry-reviews',
        [
            ( map { $_->[0]->rest_data() } $vendor->comments()->all() ),
            (
                map { $self->_rating_as_rest_data( @{$_} ) }
                    $vendor->ratings_without_reviews()->all()
            ),
        ],
    );
}

# XXX - eventually we should combine rating and review into the same table and
# just allow empty reviews.
sub _rating_as_rest_data {
    my $self   = shift;
    my $rating = shift;
    my $user   = shift;

    return {
        last_modified_datetime => undef,
        review                 => undef,
        body                   => { content => undef },
        rating                 => $rating->rating(),
        user                   => $user->rest_data( include_related => 0 ),
    };
}

sub reviews_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('reviews')->set_is_selected(1);

    my $vendor = $c->stash()->{vendor};

    $c->stash()->{comments} = $vendor->comments()
        if $vendor->review_count();

    $c->stash()->{ratings} = $vendor->ratings_without_reviews()
        if $vendor->ratings_without_review_count();

    $c->stash()->{template} = '/entry/reviews';
}

sub reviews_POST : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to write a review. If you don't have an account you can create one now.},
    );

    my $vendor = $c->stash()->{vendor};

    my $comment = $self->_comment_post(
        $c, $vendor,
        entry_uri( vendor => $vendor, path => 'review_form' ),
    );

    if ( $c->vg_user()->user_id() == $comment->user_id() ) {
        $c->add_message(
            'Thanks for your review of ' . $vendor->name() . '.' );
    }
    else {
        $c->add_message('The review has been updated.');
    }

    $c->redirect_and_detach( entry_uri( vendor => $vendor ) );
}

sub _set_review : Chained('_set_vendor') : PathPart('review') : CaptureArgs(1)
{
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    my $vendor = $c->stash()->{vendor};

    my $user = VegGuide::User->new( user_id => $user_id );
    my $comment = $vendor->comment_by_user($user);

    $c->redirect_and_detach('/')
        unless $comment;

    $c->stash()->{comment} = $comment;
}

sub review_confirm_deletion : Chained('_set_review') :
    PathPart('deletion_confirmation_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to delete a review. If you don't have an account you can create one now.},
    );

    my $comment = $c->stash()->{comment};

    $c->_redirect_with_error(
        error => 'You do not have permission to delete this review.',
        uri   => '/',
    ) unless $c->vg_user()->can_delete_comment($comment);

    my $subject
        = $comment->user_id() == $c->vg_user()->user_id()
        ? 'your review'
        : 'the review you specified';

    my $vendor = $c->stash()->{vendor};

    $c->stash()->{thing} = 'review';
    $c->stash()->{name}  = $subject;

    $c->stash()->{uri} = entry_uri( vendor => $vendor,
        path => 'review/' . $comment->user_id() );

    $c->stash()->{template} = '/shared/deletion-confirmation-form';
}

sub review : Chained('_set_review') : PathPart('') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub review_DELETE : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to delete a review. If you don't have an account you can create one now.},
    );

    my $comment = $c->stash()->{comment};

    $c->_redirect_with_error(
        error => 'You do not have permission to delete this review.',
        uri   => '/',
    ) unless $c->vg_user()->can_delete_comment($comment);

    my $subject
        = $comment->user_id() == $c->vg_user()->user_id()
        ? 'Your review'
        : 'The review you specified';

    $comment->delete( calling_user => $c->vg_user() );

    $c->add_message("$subject has been deleted.");

    $c->redirect_and_detach( entry_uri( vendor => $c->stash()->{vendor} ) );
}

sub edit_hours_form : Chained('_set_vendor') : PathPart('edit_hours_form') :
    Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to edit an entry's hours. If you don't have an account you can create one now.},
    );

    $c->stash()->{template} = '/entry/edit-hours-form';
}

sub hours : Chained('_set_vendor') : PathPart('hours') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub hours_POST : Private {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to update an entry's hours. If you don't have an account you can create one now.},
    );

    my $vendor = $c->stash()->{vendor};

    my ( $hours, $errors ) = $self->_parse_submitted_hours($c);

    if ( @{$errors} ) {
        $c->_redirect_with_error(
            error => $errors,
            uri => entry_uri( vendor => $vendor, path => 'edit_hours_form' ),
            params => $c->request()->params(),
        );
    }

    my $name = $vendor->name();
    my $msg;

    eval {
        if ( $c->vg_user()->can_edit_vendor($vendor) ) {
            $vendor->replace_hours($hours);

            $msg = "The hours for $name have been updated.";
        }
        else {
            $vendor->save_hours_suggestion(
                hours => $hours,
                comment => ( $c->request()->param('comment') || '' ),
                user_wants_notification =>
                    ( $c->request()->param('user_wants_notification') || 0 ),
                user => $c->vg_user(),
            );
            $msg
                = "Your suggestion to change the hours for $name has been recorded.";
        }
    };

    if ( my $e = $@ ) {
        $c->_redirect_with_error(
            error => $e,
            uri => entry_uri( vendor => $vendor, path => 'edit_hours_form' ),
            params => $c->request()->params(),
        );
    }

    $c->add_message($msg);

    $c->redirect_and_detach( entry_uri( vendor => $vendor ) );
}

{
    my @Days = @{ DateTime::Locale->load('en_US')->day_stand_alone_wide() };

    sub _parse_submitted_hours {
        my $self = shift;
        my $c    = shift;

        my @errors;
        my @hours;

        for my $d ( 0 .. 6 ) {
            if ( $c->request()->param("is-closed-$d") ) {
                $hours[$d] = [ { open_minute => -1, close_minute => 0 } ];
            }

            my $hours0 = $c->request()->param("hours-$d-0");

            next unless defined $hours0 && length $hours0;

            if ( $hours0 =~ /^\s* s/xism ) {
                if ($d) {
                    $hours[$d] = $hours[ $d - 1 ];
                }
                else {
                    push @errors,
                        q{You cannot use "same" to describe the hours for Monday};
                }
                next;
            }

            my $range = VegGuide::Vendor->HoursRangeToMinutes($hours0);

            if ( ref $range ) {
                push @{ $hours[$d] }, $range;
            }
            else {
                push @errors, "$Days[$d] - $range";
            }

            my $hours1 = $c->request()->param("hours-$d-1");

            if ( defined $hours1 && length $hours1 ) {
                my $range = VegGuide::Vendor->HoursRangeToMinutes( $hours1,
                    'assume pm' );

                if ( ref $range ) {
                    push @{ $hours[$d] }, $range;
                }
                else {
                    push @errors, "$Days[$d] - $range";
                }
            }
        }

        return \@hours, \@errors;
    }
}

sub _set_vendor_image : Chained('_set_vendor') : PathPart('image') :
    CaptureArgs(1) {
    my $self          = shift;
    my $c             = shift;
    my $display_order = shift;

    my $vendor = $c->stash()->{vendor};

    $c->stash()->{image} = VegGuide::VendorImage->new(
        vendor_id     => $vendor->vendor_id(),
        display_order => $display_order,
    );
}

sub image : Chained('_set_vendor_image') : PathPart('') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub image_GET {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};

    my $rest_data;

    my $image = $c->stash()->{image};

    if ($image) {
        $rest_data = $image->rest_data();

        my $display_order = $image->display_order();

        my $image_count = $vendor->image_count();
        $rest_data->{next} = $display_order + 1
            if $display_order + 1 <= $image_count;
        $rest_data->{previous} = $display_order - 1
            if $display_order > 1;
    }

    return $self->status_ok(
        $c,
        entity => $rest_data,
    );
}

sub image_PUT {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};
    my $image  = $c->stash()->{image};

    if ( $c->request()->param('display_order') ) {
        $c->redirect_and_detach('/')
            unless $c->vg_user()->can_edit_vendor($vendor);

        $image->make_image_first();
    }
    else {
        $c->redirect_and_detach('/')
            unless $c->vg_user()->can_edit_vendor_image($image);

        $image->update( caption => $c->request()->param('caption') );
    }

    $c->redirect_and_detach(
        entry_uri( vendor => $vendor, path => 'images_form' ) );
}

sub image_DELETE {
    my $self = shift;
    my $c    = shift;

    my $vendor = $c->stash()->{vendor};
    my $image  = $c->stash()->{image};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_vendor_image($image);

    $image->delete();

    $c->add_message('The image has been deleted.');

    $c->redirect_and_detach(
        entry_uri( vendor => $vendor, path => 'images_form' ) );
}

sub image_confirm_deletion : Chained('_set_vendor_image') :
    PathPart('deletion_confirmation_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $image = $c->stash()->{image};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_vendor_image($image);

    $c->stash()->{thing} = 'image';
    $c->stash()->{name}  = 'it';
    $c->stash()->{img}   = $image->small_uri();

    $c->stash()->{uri} = entry_image_uri( image => $image );

    $c->stash()->{template} = '/shared/deletion-confirmation-form';
}

sub images_form : Chained('_set_vendor') : PathPart('images_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_auth(
        $c,
        q{You must be logged in to edit an entry. If you don't have an account you can create one now.},
    );

    $c->stash()->{images} = [ $c->stash()->{vendor}->images() ];

    $c->stash()->{template} = '/entry/images-form';
}

sub image_POST {
    my $self = shift;
    my $c    = shift;

    my $file = $c->request()->upload('image');

    my $vendor = $c->stash()->{vendor};

    eval {
        die "You must pick a file.\n"
            unless $file && $file->tempname();

        VegGuide::VendorImage->create_from_file(
            vendor  => $vendor,
            user    => $c->vg_user(),
            caption => $c->request()->param('caption'),
            file    => $file->tempname(),
        );
    };

    if ( my $e = $@ ) {
        my $params = $c->request()->parameters();

        $c->_redirect_with_error(
            error  => $e,
            uri    => entry_uri( vendor => $vendor, path => 'images_form' ),
            params => $params,
        );
    }

    $c->redirect_and_detach(
        entry_uri( vendor => $vendor, path => 'images_form' ) );
}

sub images : Chained('_set_vendor') : PathPart('images') : Args(0) :
    ActionClass('+VegGuide::Action::REST') {
}

sub images_GET : Private {
    my $self = shift;
    my $c    = shift;

    $self->_rest_response(
        $c,
        'entry-images',
        [
            map { $_->rest_data() } $c->stash()->{vendor}->images()
        ],
    );
}

{
    my %SearchConfig = (
        captured_path_position => 2,
        search_class           => 'VegGuide::Search::Vendor::ByLatLong',
        extra_params           => sub {
            my $caps = $_[0]->request()->captures();
            return (
                latitude  => $caps->[0],
                longitude => $caps->[1],
            );
        },
    );

    # XXX - Catalyst makes me match the uri-encoded version, but only with the CGI engine (grr)
    sub near_filter :
        LocalRegex('^near/(-?[\d\.]+)(?:%2C|,)(-?[\d\.]+)(?:/filter(?:/(.*)))?$')
        : ActionClass('+VegGuide::Action::REST') {
    }

    sub near_filter_GET_html : Private {
        my $self = shift;
        my $c    = shift;

        $self->_set_search_in_stash( $c, %SearchConfig );

        my $search = $c->stash()->{search};

        return unless $search;

        $self->_add_search_tabs( $c, $search );

        $c->tab_by_id('results')->set_is_selected(1);

        $c->response()->breadcrumbs()->add(
            uri   => $search->uri(),
            label => $search->title(),
        );

        $c->stash()->{template} = '/site/entry-search-results';
    }

    sub near_filter_GET {
        my $self = shift;
        my $c    = shift;

        $self->_set_search_in_stash( $c, %SearchConfig );

        my $search = $c->stash()->{search};

        my $count = $search->count();

        unless ($count) {
            $self->status_ok(
                $c,
                entity => {},
            );

            return;
        }

        my $vendors = $search->vendors();

        my @entries;

        my $loc;
        while ( my $vendor = $vendors->next() ) {
            $loc ||= $vendor->location();

            my $distance = $vendor->distance_from(
                latitude  => $search->latitude(),
                longitude => $search->longitude(),
                unit      => $search->unit(),
            );

            my $with_units = $distance . ' ' . $search->unit();
            $with_units .= 's' unless $distance == 1;

            push @entries, {
                uri      => entry_uri( vendor => $vendor ),
                name     => $vendor->name(),
                distance => $with_units,
                };
        }

        my %location = (
            name   => $loc->name(),
            parent => (
                  $loc->parent()
                ? $loc->parent()->name()
                : q{}
            ),
            uri => region_uri( location => $loc ),
        );

        if ($count > 10 ) {
            $search->set_cursor_params( page => 1, limit => $c->vg_user()->entries_per_page() );
            $location{search_uri} = $search->uri();
        }

        $self->status_ok(
            $c,
            entity => {
                count    => $count,
                entries  => \@entries,
                location => \%location,
            },
        );
    }

    sub near_filter_POST : Private {
        my $self = shift;
        my $c    = shift;

        return $self->_search_post( $c, 0, %SearchConfig );
    }

    sub near_map :
        LocalRegex('^near/(-?[\d\.]+)(?:%2C|,)(-?[\d\.]+)/map(?:/(.*))?$') :
        ActionClass('+VegGuide::Action::REST') {
    }

    sub near_map_GET_html {
        my $self = shift;
        my $c    = shift;

        $self->_set_map_search_in_stash( $c, %SearchConfig );

        my $search = $c->stash()->{search};

        return unless $search;

        $self->_add_search_tabs( $c, $search );

        $c->tab_by_id('map')->set_is_selected(1);

        $c->response()->breadcrumbs()->add(
            uri   => $search->uri(),
            label => $search->title(),
        );

        $c->stash()->{template} = '/site/entry-search-results-map';
    }

    sub near_map_POST : Private {
        my $self = shift;
        my $c    = shift;

        return $self->_search_post( $c, 'is map', %SearchConfig );
    }

    sub near_printable :
        LocalRegex('^near/(-?[\d\.]+)(?:%2C|,)(-?[\d\.]+)/printable(?:/(.*))?$')
    {
        my $self = shift;
        my $c    = shift;

        $self->_set_printable_search_in_stash( $c, %SearchConfig );

        return unless $c->stash()->{search};

        $c->stash()->{template} = '/shared/printable-entry-list';
    }
}

{
    my %SearchConfig = (
        captured_path_position => 1,
        search_class           => 'VegGuide::Search::Vendor::ByName',
        extra_params =>
            sub { return ( name => $_[0]->request()->captures()->[0] ) },
    );

    # XXX - Catalyst makes me match on the uri-encoded version? wtf?
    sub search_filter : LocalRegex('^search/([^/]+)(?:/filter(?:/(.*)))?$') :
        ActionClass('+VegGuide::Action::REST') {
    }

    sub search_filter_GET_html : Private {
        my $self = shift;
        my $c    = shift;

        $self->_set_search_in_stash( $c, %SearchConfig );

        my $search = $c->stash()->{search};

        return unless $search;

        $self->_add_search_tabs( $c, $search );

        $c->tab_by_id('results')->set_is_selected(1);

        $c->response()->breadcrumbs()->add(
            uri   => $search->uri(),
            label => $search->title(),
        );

        $c->stash()->{template} = '/site/entry-search-results';
    }

    sub search_filter_POST : Private {
        my $self = shift;
        my $c    = shift;

        return $self->_search_post( $c, 0, %SearchConfig );
    }

    sub search_map : LocalRegex('^search/([^/]+)/map(?:/(.*))?$') :
        ActionClass('+VegGuide::Action::REST') {
    }

    sub search_map_GET_html {
        my $self = shift;
        my $c    = shift;

        $self->_set_map_search_in_stash( $c, %SearchConfig );

        my $search = $c->stash()->{search};

        return unless $search;

        $self->_add_search_tabs( $c, $search );

        $c->tab_by_id('map')->set_is_selected(1);

        $c->response()->breadcrumbs()->add(
            uri   => $search->uri(),
            label => $search->title(),
        );

        $c->stash()->{template} = '/site/entry-search-results-map';
    }

    sub search_map_POST : Private {
        my $self = shift;
        my $c    = shift;

        return $self->_search_post( $c, 'is map', %SearchConfig );
    }

    sub search_printable : LocalRegex('^search/([^/]+)/printable(?:/(.*))?$')
    {
        my $self = shift;
        my $c    = shift;

        $self->_set_printable_search_in_stash( $c, %SearchConfig );

        return unless $c->stash()->{search};

        $c->stash()->{template} = '/shared/printable-entry-list';
    }
}

sub _add_search_tabs {
    my $self   = shift;
    my $c      = shift;
    my $search = shift;

    $c->add_tab(
        {
            uri     => $search->uri(),
            label   => 'Results',
            tooltip => 'Search results',
            id      => 'results',
        }
    );

    $c->add_tab(
        {
            uri     => $search->map_uri(),
            label   => 'Map',
            tooltip => 'Map of results',
            id      => 'map',
        }
    );

    $c->add_tab(
        {
            uri     => $search->printable_uri(),
            label   => 'Printable',
            tooltip => 'Printable list of results',
            id      => 'printable',
        }
    );
}

sub ungeocoded : Local : ActionClass('+VegGuide::Action::REST') {
}

sub ungeocoded_GET_html {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{vendors} = VegGuide::Vendor->UnGeocoded();

    $c->response()->breadcrumbs()->add(
        uri   => '/entry/ungeocoded',
        label => 'Un-geocoded entries',
    );

    $c->stash()->{template} = '/site/ungeocoded-entry-list';
}

sub ungeocoded_POST {
    my $self = shift;
    my $c    = shift;

    my @ids = $c->request->param('vendor_id');

    for my $id (@ids) {
        my $vendor = VegGuide::Vendor->new( vendor_id => $id );
        $vendor->update_geocode_info();

        sleep 0.2;
    }

    $c->redirect_and_detach('/entry/ungeocoded');
}

__PACKAGE__->meta()->make_immutable();

1;
