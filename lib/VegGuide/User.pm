package VegGuide::User;

use strict;
use warnings;

use VegGuide::Exceptions qw( auth_error data_validation_error );
use VegGuide::Validate
    qw( validate validate_with validate_pos SCALAR UNDEF BOOLEAN LOCATION_TYPE );

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema()->User_t() );

use DateTime;
use DateTime::Format::MySQL;
use Digest::SHA1 ();
use Email::Valid ();
use Image::Size qw( imgsize );
use List::Util qw( sum );
use Sys::Hostname ();
use URI::FromHash qw( uri );
use VegGuide::Config;
use VegGuide::Email;
use VegGuide::Image;
use VegGuide::Location;
use VegGuide::UserActivityLog;
use VegGuide::User::Guest;
use VegGuide::Util qw( string_is_empty );

sub _new_row {
    my $class = shift;
    my %p     = validate_with(
        params => \@_,
        spec   => {
            email_address => { type => SCALAR | UNDEF, optional => 1 },
            password      => { type => SCALAR | UNDEF, optional => 1 },
            openid_uri    => { type => SCALAR | UNDEF, optional => 1 },
            forgot_password_digest => { type => SCALAR, optional => 1 },
            real_name              => { type => SCALAR, optional => 1 },
        },
        allow_extra => 1,
    );

    my $schema = VegGuide::Schema->Connect();

    my @where;
    if ( exists $p{email_address} ) {
        push @where,
            [ $schema->User_t->email_address_c, '=', $p{email_address} ];

        if ( exists $p{password} ) {
            my $sha1 = Digest::SHA1::sha1_base64(
                Encode::encode( 'utf-8', $p{password} ) );
            push @where, [ $schema->User_t->password_c, '=', $sha1 ];
        }
    }
    elsif ( exists $p{openid_uri} ) {
        push @where,
            (
            [
                $schema->User_t->openid_uri_c,
                '=', $p{openid_uri}
            ],
            );
    }
    elsif ( exists $p{forgot_password_digest} ) {
        my $yesterday = DateTime->now->subtract( days => 1 );

        push @where,
            (
            [
                $schema->User_t->forgot_password_digest_c,
                '=', $p{forgot_password_digest}
            ],
            [
                $schema->User_t->forgot_password_digest_datetime_c,
                '>=', DateTime::Format::MySQL->format_datetime($yesterday)
            ],
            );
    }
    elsif ( exists $p{real_name} ) {
        push @where, [ $schema->User_t->real_name_c, '=', $p{real_name} ];
    }

    return $schema->User_t->one_row( where => \@where );
}

sub create {
    my $class = shift;

    return $class->SUPER::create(
        @_,
        creation_datetime => VegGuide::Schema->Connect()->sqlmaker()->NOW(),
    );
}

sub _validate_data {
    my $self      = shift;
    my $data      = shift;
    my $is_update = ref $self ? 1 : 0;

    $self->_convert_empty_strings($data);

    delete $data->{password}  unless defined $data->{password};
    delete $data->{password2} unless defined $data->{password2};

    my @errors;
    if ( !$is_update || exists $data->{email_address} ) {
        push @errors, "Invalid email address"
            if ( !defined $data->{email_address}
            || $data->{email_address} =~ /\@vegguide\.org$/
            || !Email::Valid->address( $data->{email_address} ) );

        if (
            !$is_update
            || ( defined $data->{email_address}
                && $data->{email_address} ne $self->email_address )
            ) {
            push @errors,
                "That email address is already registered! Did you forget your password?"
                if (
                exists $data->{email_address}
                && VegGuide::User->new(
                    email_address => $data->{email_address}
                )
                );
        }
    }

    if (
        defined $data->{openid_uri}
        && (
            !$is_update
            || ( !defined $self->openid_uri()
                || $data->{openid_uri} ne $self->openid_uri() )
        )
        ) {
        push @errors,
            "That OpenID URL is already in use! Did you forget your password?"
            if VegGuide::User->new( openid_uri => $data->{openid_uri} );
    }

    if (
        defined $data->{real_name}
        && (  !$is_update
            || $data->{real_name} ne $self->real_name )
        ) {
        push @errors,
            "That name is already being used! Did you forget your password?"
            if ( exists $data->{real_name}
            && VegGuide::User->new( real_name => $data->{real_name} ) );
    }

    # This is a weird thing to check for, but there seems to be some
    # bot or browser or something that submits user names like this
    if ( defined $data->{real_name} ) {
        for my $re (
            qr{multipart/alternative}i,
            qr{content-type:}i,
            qr{content-transfer-encoding}i,
            ) {
            if ( $data->{real_name} =~ /$re/ ) {
                push @errors, "That name is not valid.";
                last;
            }
        }

        # Spam bots were making accounts with names like "<a href=...>".
        push @errors, "That name is not valid."
            if $data->{real_name} =~ /href=/;
    }

    if ( !$is_update || defined $data->{password} ) {
        push @errors, "Must provide a password."
            unless defined $data->{password};

        unless ( string_is_empty( $data->{password} ) ) {
            push @errors, "The two passwords must be identical."
                unless $data->{password2}
                    && $data->{password} eq $data->{password2};

            push @errors, "Your password must be at least 6 characters long."
                unless length $data->{password} >= 6;
        }
    }

    if ( !$is_update || exists $data->{real_name} ) {
        push @errors, "Must provide a name."
            unless defined $data->{real_name} && length $data->{real_name};
    }

    data_validation_error error => "One or more data validation errors",
        errors                  => \@errors
        if @errors;

    delete $data->{password2};

    $data->{home_page} = VegGuide::Util::normalize_uri( $data->{home_page} )
        if defined $data->{home_page};

    $data->{password}
        = Digest::SHA1::sha1_base64(
        Encode::encode( 'utf-8', $data->{password} ) )
        if defined $data->{password};
}

{
    my %char_cols
        = map { $_->name => 1 }
        grep { $_->is_character || $_->is_blob } __PACKAGE__->columns;

    $char_cols{password2} = 1;

    my %num_cols
        = map { $_->name => 1 }
        grep { $_->is_numeric } __PACKAGE__->columns;

    sub _convert_empty_strings {
        shift;

        VegGuide::Util::convert_empty_strings( shift, \%char_cols,
            \%num_cols );
    }
}

sub forgot_password {
    my $self = shift;

    my $digest = Digest::SHA1::sha1_base64(
        time,
        $self->email_address,
        VegGuide::Config->ForgotPWSecret(),
    );

    # makes it possible to use this as part of a URI path
    $digest =~ s{/}{.}g;
    $digest =~ s{\+}{-}g;

    $self->SUPER::update(
        forgot_password_digest => $digest,
        forgot_password_digest_datetime =>
            VegGuide::Schema->Connect()->sqlmaker()->NOW(),
    );

    my $uri = uri(
        scheme => 'http',
        host   => VegGuide::Config->CanonicalWebHostname(),
        path   => "/user/change_password_form/$digest",
    );

    VegGuide::Email->Send(
        to       => $self->email_address,
        subject  => 'Forgot your password for VegGuide.Org?',
        template => 'forgot-password',
        params   => { uri => $uri },
    );
}

sub change_password {
    my $self = shift;

    $self->update(
        @_,
        forgot_password_digest          => undef,
        forgot_password_digest_datetime => undef,
    );
}

sub can_edit_location {
    my $self = shift;

    return 1 if $self->is_admin;
}

sub is_location_owner {
    my $self = shift;
    my ($location) = validate_pos(
        @_,
        { isa => 'VegGuide::Location' },
    );

    return 1 if $self->is_admin;

    my $schema = VegGuide::Schema->Connect();

    return $schema->LocationOwner_t->function(
        select => 1,
        where  => [
            [ $schema->LocationOwner_t->user_id_c, '=', $self->user_id ],
            [
                $schema->LocationOwner_t->location_id_c,
                'IN', $location->location_id, $location->ancestor_ids
            ],
        ]
    );
}

sub owned_locations {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->join(
            select => $schema->Location_t,
            join   => [ $schema->tables( 'Location', 'LocationOwner' ) ],
            where  => [
                [ $schema->LocationOwner_t->user_id_c, '=', $self->user_id ],
            ],
            order_by => $schema->Location_t->name_c,
        )
    );
}

sub can_delete_location {
    my $self = shift;
    my ($location) = validate_pos(
        @_,
        { isa => 'VegGuide::Location' },
    );

    return 1 if $self->is_admin;
}

sub can_edit_comment {
    my $self = shift;
    my ($comment) = validate_pos(
        @_,
        { isa => 'VegGuide::Comment' },
    );

    return 1 if $self->is_admin;

    return (   $comment->user_id == $self->user_id
            || $self->is_location_owner( $comment->location ) );
}

sub can_edit_review {
    my $self = shift;
    my ($comment) = validate_pos(
        @_,
        { isa => 'VegGuide::Comment' },
    );

    return 1 if $self->is_admin;

    return $comment->user_id == $self->user_id;
}

sub can_delete_comment {
    my $self = shift;
    my ($comment) = validate_pos(
        @_,
        { isa => 'VegGuide::Comment' },
    );

    return 1 if $self->is_admin;

    return $comment->user_id == $self->user_id;
}

sub can_edit_vendor {
    my $self = shift;
    my ($vendor) = validate_pos(
        @_,
        { isa => 'VegGuide::Vendor' },
    );

    return 1 if $self->is_admin;

    return (   $vendor->user_id == $self->user_id
            || $self->is_location_owner( $vendor->location ) );
}

sub can_delete_vendor {
    my $self = shift;
    my ($comment) = validate_pos(
        @_,
        { isa => 'VegGuide::Vendor' },
    );

    return 1 if $self->is_admin;
}

sub can_mark_vendor_as_closed {
    my $self = shift;
    my ($vendor) = validate_pos(
        @_,
        { isa => 'VegGuide::Vendor' },
    );

    return 1 if $self->is_admin;

    # add something later to let other users (presumably a vendor's
    # owner/manager) edit this as well.
}

sub can_edit_vendor_image {
    my $self = shift;
    my ($image) = validate_pos(
        @_,
        { isa => 'VegGuide::VendorImage' },
    );

    return 1 if $self->is_admin;

    return (   $image->user_id == $self->user_id
            || $self->can_edit_vendor( $image->vendor() ) );
}

sub can_delete_vendor_image {
    my $self = shift;
    my ($image) = validate_pos(
        @_,
        { isa => 'VegGuide::VendorImage' },
    );

    return 1 if $self->is_admin;

    return 1 if $image->user_id == $self->user_id;
}

sub can_edit_user {
    my $self = shift;
    my ($user) = validate_pos(
        @_,
        { isa => 'VegGuide::User' },
    );

    return 1 if $self->is_admin;

    return $user->user_id == $self->user_id;
}

sub can_delete_user {
    my $self = shift;
    my ($user) = validate_pos(
        @_,
        { isa => 'VegGuide::User' },
    );

    return 1 if $self->is_admin;
}

sub can_edit_skin {
    my $self = shift;
    my ($skin) = validate_pos(
        @_,
        { isa => 'VegGuide::Skin' },
    );

    return 1 if $self->is_admin;

    return $skin->owner_user_id == $self->user_id;
}

sub can_edit_team {
    my $self = shift;
    my ($team) = validate_pos(
        @_,
        { isa => 'VegGuide::Team' },
    );

    return 1 if $self->is_admin;

    return $team->owner_user_id == $self->user_id;
}

sub skin_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->Skin_t->row_count(
        where => [ $schema->Skin_t->owner_user_id_c, '=', $self->user_id ],
    );
}

sub skins {
    my $self = shift;

    return VegGuide::Skin->All
        if $self->is_admin;

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->Skin_t->rows_where(
            where =>
                [ $schema->Skin_t->owner_user_id_c, '=', $self->user_id ],
        )
    );
}

sub vendor_count {
    my $self = shift;
    my %p = validate( @_, { location => LOCATION_TYPE( default => undef ) } );

    my $schema = VegGuide::Schema->Connect();

    my @where = [ $schema->Vendor_t->user_id_c, '=', $self->user_id ],;
    push @where,
        [ $schema->Vendor_t->location_id_c, '=', $p{location}->location_id() ]
        if $p{location};

    return $schema->Vendor_t->row_count( where => \@where );
}

sub vendors {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->Vendor_t->rows_where(
            where => [ $schema->Vendor_t->user_id_c, '=', $self->user_id ],
        )
    );
}

sub vendors_by_location {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my ( $lp_join, $lp_order_by )
        = VegGuide::Location->LocationAndParentClauses();

    push @{$lp_order_by}, $schema->Vendor_t()->sortable_name_c();

    return $self->cursor(
        $schema->join(
            select => $schema->Vendor_t(),
            join   => [
                [ $schema->tables( 'Vendor', 'Location' ) ],
                $lp_join,
            ],
            where =>
                [ $schema->Vendor_t()->user_id_c(), '=', $self->user_id() ],
            order_by => $lp_order_by,
        )
    );
}

sub rating_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorRating_t->row_count(
        where => [ $schema->VendorRating_t->user_id_c, '=', $self->user_id ],
    );
}

sub ratings_without_review_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my $reviewed_vendor_subselect = $self->_reviewed_vendor_subselect();

    return $schema->row_count(
        join  => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
        where => [
            [ $schema->VendorRating_t()->user_id_c(), '=', $self->user_id() ],
            [
                $schema->Vendor_t()->vendor_id_c(), 'NOT IN',
                $reviewed_vendor_subselect
            ],
        ]
    );
}

sub ratings_without_reviews_by_location {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my ( $lp_join, $lp_order_by )
        = VegGuide::Location->LocationAndParentClauses();

    push @{$lp_order_by}, $schema->Vendor_t()->sortable_name_c();

    my $reviewed_vendor_subselect = $self->_reviewed_vendor_subselect();

    $self->cursor(
        $schema->join(
            select => [ $schema->tables( 'VendorRating', 'Vendor' ) ],
            join   => [
                [ $schema->tables( 'Vendor', 'VendorRating' ) ],
                [ $schema->tables( 'Vendor', 'Location' ) ],
                $lp_join
            ],
            where => [
                [
                    $schema->VendorRating_t()->user_id_c(), '=',
                    $self->user_id()
                ],
                [
                    $schema->Vendor_t()->vendor_id_c(), 'NOT IN',
                    $reviewed_vendor_subselect
                ],
            ],
            order_by => $lp_order_by,
        )
    );
}

sub _reviewed_vendor_subselect {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my $sql = $schema->sqlmaker();
    $sql->select( $schema->VendorComment_t()->vendor_id_c() )
        ->from( $schema->VendorComment_t() )
        ->where( $schema->VendorComment_t()->user_id_c(), '=',
        $self->user_id() );

    return $sql;
}

sub review_count {
    my $self = shift;
    my %p = validate( @_, { location => LOCATION_TYPE( default => undef ) } );

    my $schema = VegGuide::Schema->Connect();

    my @where = [ $schema->VendorComment_t->user_id_c, '=', $self->user_id ],;
    push @where,
        [ $schema->Vendor_t->location_id_c, '=', $p{location}->location_id() ]
        if $p{location};

    return $schema->row_count(
        join  => [ $schema->tables( 'Vendor', 'VendorComment' ) ],
        where => \@where,
    );
}

sub reviews_by_location {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my ( $lp_join, $lp_order_by )
        = VegGuide::Location->LocationAndParentClauses();

    push @{$lp_order_by}, $schema->Vendor_t()->sortable_name_c();

    $self->cursor(
        $schema->join(
            select => [ $schema->tables( 'VendorComment', 'Vendor' ) ],
            join   => [
                [ $schema->tables( 'Vendor', 'VendorComment' ) ],
                [ $schema->tables( 'Vendor', 'Location' ) ],
                $lp_join
            ],
            where => [
                $schema->VendorComment_t()->user_id_c(), '=', $self->user_id()
            ],
            order_by => $lp_order_by,
        )
    );
}

sub update_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my @where = (
        [ $schema->UserActivityLog_t->user_id_c, '=', $self->user_id ],
        [
            $schema->UserActivityLog_t->user_activity_log_type_id_c,
            'IN',
            $self->entry_update_activity_type_ids,
        ],
    );

    return $schema->UserActivityLog_t->row_count( where => \@where );
}

sub image_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my @where = ( $schema->VendorImage_t->user_id_c, '=', $self->user_id );

    return $schema->VendorImage_t->row_count( where => \@where );
}

sub top_vendors {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->join(
            select => $schema->Vendor_t(),
            join   => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
            where  => [
                [ $schema->VendorRating_t()->rating_c(), '=', 5 ],
                [
                    $schema->VendorRating_t()->user_id_c(), '=',
                    $self->user_id()
                ],
            ],
            order_by => $schema->Vendor_t()->sortable_name_c(),
        )
    );
}

sub bottom_vendors {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->join(
            select => $schema->Vendor_t(),
            join   => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
            where  => [
                [ $schema->VendorRating_t()->rating_c(), '=', 1 ],
                [
                    $schema->VendorRating_t()->user_id_c(), '=',
                    $self->user_id()
                ],
            ],
            order_by => $schema->Vendor_t()->sortable_name_c(),
        )
    );
}

sub average_rating {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorRating_t()->function(
        select =>
            $schema->sqlmaker()->AVG( $schema->VendorRating_t()->rating_c() ),
        where =>
            [ $schema->VendorRating_t()->user_id_c(), '=', $self->user_id() ],
    );
}

sub delete {
    my $self = shift;
    my %p    = validate(
        @_,
        { calling_user => { isa => 'VegGuide::User' } },
    );

    if ( $self->vendor_count && $self->user_id == $p{calling_user}->user_id )
    {
        data_validation_error
            "A user cannot delete their own account while they still have vendors.";
    }

    my $vendors = $self->vendors;

    while ( my $vendor = $vendors->next ) {
        $vendor->update(
            user_id => $p{calling_user}->user_id,
            user    => $p{calling_user},
        );
    }

    $self->SUPER::delete;
}

sub is_subscribed_to_location {
    my $self = shift;
    my %p    = validate(
        @_,
        { location => { isa => 'VegGuide::Location' } },
    );

    my $schema = VegGuide::Schema->Connect();

    return $schema->UserLocationSubscription_t->function(
        select => 1,
        where  => [
            [
                $schema->UserLocationSubscription_t->user_id_c,
                '=', $self->user_id
            ],
            [
                $schema->UserLocationSubscription_t->location_id_c,
                '=', $p{location}->location_id
            ],
        ]
    );
}

sub subscribe_to_location {
    my $self = shift;
    my %p    = validate(
        @_,
        { location => { isa => 'VegGuide::Location' } },
    );

    # insert may fail if user is already subscribed
    eval {
        VegGuide::Schema->Connect()->UserLocationSubscription_t->insert(
            values => {
                user_id     => $self->user_id,
                location_id => $p{location}->location_id,
            },
        );
    };
}

sub unsubscribe_from_location {
    my $self = shift;
    my %p    = validate(
        @_,
        { location => { isa => 'VegGuide::Location' } },
    );

    my $sub
        = VegGuide::Schema->Connect()->UserLocationSubscription_t->row_by_pk(
        pk => {
            user_id     => $self->user_id,
            location_id => $p{location}->location_id,
        },
        );

    $sub->delete if $sub;
}

sub send_subscription_email {
    my $self = shift;

    my $new_vendors = $self->new_entries_for_subscription(@_);

    return unless $new_vendors;

    my %params = (
        vendors1 => $new_vendors,
        vendors2 => $self->new_entries_for_subscription(@_),
        user     => $self,
    );

    VegGuide::Email->Send(
        to       => $self->email_address,
        subject  => 'VegGuide.Org watch list updates',
        template => 'watch-list',
        params   => \%params,
    );
}

sub new_entries_for_subscription {
    my $self = shift;
    my %p    = validate(
        @_,
        { days => { type => SCALAR, default => 7 } },
    );

    my $locations = $self->subscribed_locations;

    my @location_ids;
    while ( my $location = $locations->next ) {
        push @location_ids, $location->location_id, $location->descendant_ids;
    }

    # get unique set of location ids
    my %location_ids = map { $_ => 1 } @location_ids;

    return unless keys %location_ids;

    my $since = DateTime->today()->subtract( days => $p{days} );

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->join(
            select => $schema->Vendor_t,
            join   => [ $schema->tables( 'Vendor', 'Location' ) ],
            where  => [
                [
                    $schema->Vendor_t->location_id_c,
                    'IN', keys %location_ids
                ],
                [
                    $schema->Vendor_t->creation_datetime_c,
                    '>', DateTime::Format::MySQL->format_datetime($since)
                ],
            ],
            order_by => [
                $schema->Location_t->name_c, 'ASC',
                $schema->Vendor_t->name_c,   'ASC',
            ],
        )
    );
}

sub has_subscriptions {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->UserLocationSubscription_t->function(
        select => 1,
        where  => [
            $schema->UserLocationSubscription_t->user_id_c,
            '=', $self->user_id
        ],
    );
}

sub subscribed_locations {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    $self->cursor(
        $schema->join(
            select => $schema->Location_t,
            join =>
                [ $schema->tables( 'Location', 'UserLocationSubscription' ) ],
            where => [
                $schema->UserLocationSubscription_t->user_id_c,
                '=', $self->user_id
            ],
            order_by => [ $schema->Location_t->name_c, 'ASC' ],
        )
    );
}

sub is_team_member {
    my $self = shift;
    my $team = shift;

    return 1 if $self->team_id && $self->team_id == $team->team_id;
}

sub team {
    my $self = shift;

    return $self->{team} if $self->{team};

    return unless $self->team_id;

    return $self->{team} = VegGuide::Team->new( team_id => $self->team_id );
}

sub viewable_suggestion_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    if ( $self->is_admin ) {
        return $schema->VendorSuggestion_t->row_count;
    }
    else {
        return $schema->row_count( $self->_viewable_suggestion_params );
    }
}

sub viewable_suggestions {
    my $self = shift;
    my %p    = validate(
        @_, {
            order_by => { type => SCALAR, default => 'creation_datetime' },
            sort_order =>
                { type => SCALAR, default => 'DESC' },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my @order_by;
    @order_by = ( $schema->VendorSuggestion_t->creation_datetime_c,
        $p{sort_order} );

    if ( $self->is_admin ) {
        return $self->cursor(
            $schema->VendorSuggestion_t->all_rows( order_by => \@order_by ) );
    }
    else {
        return $self->cursor(
            $schema->join(
                select => $schema->VendorSuggestion_t,
                $self->_viewable_suggestion_params,
                order_by => \@order_by,
            )
        );
    }
}

sub can_edit_suggestion {
    my $self       = shift;
    my $suggestion = shift;

    return $self->can_edit_vendor( $suggestion->vendor );
}

sub _viewable_suggestion_params {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return (
        join => [
            [ $schema->tables( 'Vendor', 'VendorSuggestion' ) ],
            [ $schema->tables( 'Vendor', 'Location' ) ],
            [
                left_outer_join =>
                    $schema->tables( 'Location', 'LocationOwner' )
            ],
        ],
        where => [
            [ $schema->Vendor_t->user_id_c, '=', $self->user_id ],
            'or',
            [ $schema->LocationOwner_t->user_id_c, '=', $self->user_id ],
        ]
    );
}

sub activity_log_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->UserActivityLog_t()->row_count(
        where => [
            $schema->UserActivityLog_t()->user_id_c(), '=', $self->user_id()
        ],
    );
}

sub activity_logs {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $self->row_object->activity_logs(
            order_by => [
                $schema->UserActivityLog_t->activity_datetime_c,
                'DESC'
            ],
        )
    );
}

{
    my $types
        = VegGuide::Schema->Connect()->UserActivityLogType_t()->all_rows();
    my %types;

    while ( my $t = $types->next ) {
        $types{ $t->select('type') }
            = $t->select('user_activity_log_type_id');
    }

    my $valid_type_cb = sub { exists $types{ $_[0] } };

    sub insert_activity_log {
        my $self = shift;
        my %p    = validate(
            @_, {
                type => {
                    type      => SCALAR,
                    callbacks => { 'type is valid' => $valid_type_cb },
                },
                vendor_id   => { type => SCALAR, default => undef },
                location_id => { type => SCALAR, default => undef },
                comment     => { type => SCALAR, default => undef },
            },
        );

        my $schema = VegGuide::Schema->Connect();

        $schema->UserActivityLog_t->insert(
            values => {
                user_id                   => $self->user_id,
                user_activity_log_type_id => $types{ $p{type} },
                activity_datetime         => $schema->sqlmaker->NOW,
                comment                   => $p{comment},
                vendor_id                 => $p{vendor_id},
                location_id               => $p{location_id},
            },
        );

    }

    sub entry_update_activity_type_ids {
        return @types{ 'update vendor', 'suggestion accepted' };
    }
}

{
    my $schema = VegGuide::Schema->Connect();

    my @ids = $schema->User_t->function(
        select => $schema->User_t()->user_id_c(),
        where  => [
            $schema->User_t()->real_name_c(),
            'IN', 'VegGuide.Org', 'Admin'
        ],
    );

    sub users_excluded_from_stats {
        return @ids;
    }
}

{
    my %Desc = (
        4 => 'vegan',
        3 => 'vegetarian',
        2 => 'mostly vegetarian, but not always',
        1 => 'not vegetarian',
        0 => 'not telling',
    );

    sub VegLevelDescription {
        return $Desc{ $_[1] };
    }
}

sub veg_level_description {
    return $_[0]->VegLevelDescription( $_[0]->how_veg() );
}

sub add_image_from_file {
    my $self = shift;
    my $file = shift;

    my $image = VegGuide::Image->new( file => $file );

    $self->update( image_extension => $image->extension() );

    $image->resize( 100, 100, $self->large_image_path() );
    $image->resize( 40,  40,  $self->small_image_path() );
}

BEGIN {
    for my $size (qw( small large )) {
        my $filename_method = sub {
            return $_[0]->base_filename() . q{-} . $size . q{.}
                . $_[0]->image_extension();
        };

        my $filename_meth_name = $size . '_image_filename';
        my $path_method        = sub {
            return File::Spec->catfile( $_[0]->dir(),
                $_[0]->$filename_meth_name() );
        };

        my $uri_method = sub {
            return File::Spec::Unix->catfile( '', $_[0]->_uri_prefix(),
                $_[0]->$filename_meth_name() );
        };

        my $path_meth_name = $size . '_image_path';

        my $dimensions_key    = $size . '_image_dimensions';
        my $dimensions_method = sub {
            my $self = shift;

            $self->{$dimensions_key}
                ||= [ imgsize( $self->$path_meth_name() ) ];

            return $self->{$dimensions_key};
        };

        my $dimensions_meth_name = q{_} . $size . '_image_dimensions';
        my $width_method = sub { $_[0]->$dimensions_meth_name()->[0] };
        my $height_method = sub { $_[0]->$dimensions_meth_name()->[1] };

        no strict 'refs';
        *{$filename_meth_name}       = $filename_method;
        *{$path_meth_name}           = $path_method;
        *{ $size . '_image_uri' }    = $uri_method;
        *{$dimensions_meth_name}     = $dimensions_method;
        *{ $size . '_image_height' } = $height_method;
        *{ $size . '_image_width' }  = $width_method;
    }
}

sub has_image {
    return $_[0]->image_extension() && -f $_[0]->large_image_path();
}

sub _uri_prefix {
    my $self = shift;

    return ('user-images');
}

sub dir {
    my $self = shift;

    return File::Spec->catdir( VegGuide::Config->VarLibDir(),
        $self->_uri_prefix() );
}

sub base_filename {
    my $self = shift;

    return $self->user_id();
}

sub external_uri {
    my $self = shift;

    return unless $self->home_page();

    if ( $self->home_page() =~ m{^https?://} ) {
        return $self->home_page();
    }
    else {
        return 'http://' . $self->home_page();
    }
}

sub is_guest     {0}
sub is_logged_in {1}

sub ActiveUserCount {
    my $class = shift;

    my $sql = <<'EOF';
SELECT COUNT(*)
  FROM ( (SELECT DISTINCT(user_id) FROM VendorRating)
         UNION
         (SELECT DISTINCT(user_id) FROM VendorComment)
         UNION
         (SELECT DISTINCT(user_id) FROM LocationComment)
         UNION
         (SELECT DISTINCT(user_id) FROM Vendor)
         UNION
         (SELECT DISTINCT(user_id) FROM UserActivityLog)
       ) AS user_ids
EOF

    my $dbh = VegGuide::Schema->Connect()->driver()->handle();

    return $dbh->selectrow_arrayref($sql)->[0];
}

sub UsersWithEntriesCount {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->Vendor_t()->function(
        select => $schema->sqlmaker()->COUNT(
            $schema->sqlmaker()->DISTINCT( $schema->Vendor_t()->user_id_c() )
        )
    );
}

sub AverageVendorCount {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my $sql = <<'EOF';
SELECT AVG (vendor_count)
  FROM ( SELECT COUNT(*) AS vendor_count
           FROM Vendor
       GROUP BY user_id
         HAVING vendor_count > 0 ) AS whatever
EOF

    my $dbh = VegGuide::Schema->Connect()->driver()->handle();

    return $dbh->selectrow_arrayref($sql)->[0];
}

sub MedianVendorCount {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my $count = $class->UsersWithEntriesCount();

    my $start = int( $count / 2 );
    my $limit = $count % 2 ? 1 : 2;

    my $sql = <<"EOF";
  SELECT COUNT(*) AS vendor_count
    FROM Vendor
GROUP BY user_id
  HAVING vendor_count > 0
ORDER BY vendor_count
   LIMIT $start, $limit
EOF

    my $dbh = VegGuide::Schema->Connect()->driver()->handle();

    my $vals = $dbh->selectcol_arrayref($sql);

    return ( sum @{$vals} ) / ( scalar @{$vals} );
}

sub All {
    my $class = shift;
    my %p     = validate(
        @_, {
            real_name     => { type => SCALAR,  optional => 1 },
            email_address => { type => SCALAR,  optional => 1 },
            with_profile  => { type => BOOLEAN, default  => 0 },
            limit         => { type => SCALAR,  optional => 1 },
            start         => { type => SCALAR,  optional => 1 },
            order_by      => {
                type    => SCALAR,
                default => 'name'
            },
            sort_order => {
                type    => SCALAR,
                default => 'ASC'
            },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my $limit;
    if ( $p{limit} ) {
        $limit = $p{start} ? [ @p{ 'limit', 'start' } ] : $p{limit};
    }

    my @order_by;
    if ( $p{order_by} eq 'signup_date' ) {
        @order_by = (
            $schema->User_t->creation_datetime_c, $p{sort_order},

            # user_id increases over time
            $schema->User_t->user_id_c, $p{sort_order},
        );
    }
    elsif ( $p{order_by} eq 'email_address' ) {
        @order_by = (
            $schema->User_t->email_address_c, $p{sort_order},
            $schema->User_t->real_name_c,     'ASC',
        );
    }
    else {
        @order_by = (
            $schema->User_t->real_name_c, $p{sort_order},
        );
    }

    my %where = $class->_WhereClauseForSearch(%p);

    return $class->cursor(
        $schema->User_t->rows_where(
            order_by => \@order_by,
            %where,
            $limit ? ( limit => $limit ) : (),
        )
    );
}

sub Count {
    my $class = shift;
    my %p     = validate(
        @_, {
            real_name     => { type => SCALAR, optional => 1 },
            email_address => { type => SCALAR, optional => 1 },
            limit         => { type => SCALAR, optional => 1 },
            start         => { type => SCALAR, optional => 1 },
            order_by      => {
                type    => SCALAR,
                default => 'name'
            },
            sort_order => {
                type    => SCALAR,
                default => 'ASC'
            },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my %where = $class->_WhereClauseForSearch(%p);

    return $schema->User_t()->row_count(%where);
}

sub _WhereClauseForSearch {
    my $class = shift;
    my %p     = @_;

    my $user_t = VegGuide::Schema->Connect()->User_t();

    my %where;
    if ( $p{real_name} ) {
        $where{where} = [
            $user_t->real_name_c(),
            'LIKE', '%' . $p{real_name} . '%'
        ];
    }
    elsif ( $p{email_address} ) {
        $where{where} = [
            $user_t->email_address_c(),
            'LIKE', '%' . $p{email_address} . '%'
        ];
    }
    elsif ( $p{with_profile} ) {
        $where{where} = [
            '(',
            [ $user_t->bio_c(), '!=', undef ],
            'or',
            [ $user_t->image_extension_c(), '!=', undef ],
            ')',
        ];
    }

    return %where;
}

sub ByVendorCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit => { type => SCALAR, default => 5 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    return VegGuide::Cursor::UserWithAggregate->new(
        cursor => $schema->Vendor_t->select(
            select => [
                $schema->sqlmaker->COUNT( $schema->Vendor_t->vendor_id_c ),
                $schema->Vendor_t->user_id_c
            ],
            where => [
                $schema->Vendor_t->user_id_c,
                'NOT IN',
                $class->users_excluded_from_stats,
            ],
            group_by => $schema->Vendor_t->user_id_c,
            order_by => [
                $schema->sqlmaker->COUNT( $schema->Vendor_t->vendor_id_c ),
                'DESC',
            ],
            limit => $p{limit},
        )
    );
}

sub ByReviewCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit => { type => SCALAR, default => 5 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    return VegGuide::Cursor::UserWithAggregate->new(
        cursor => $schema->VendorComment_t->select(
            select => [
                $schema->sqlmaker->COUNT(
                    $schema->VendorComment_t->vendor_id_c
                ),
                $schema->VendorComment_t->user_id_c
            ],
            where => [
                $schema->VendorComment_t->user_id_c,
                'NOT IN',
                $class->users_excluded_from_stats,
            ],
            group_by => $schema->VendorComment_t->user_id_c,
            order_by => [
                $schema->sqlmaker->COUNT(
                    $schema->VendorComment_t->vendor_id_c
                ),
                'DESC',
            ],
            limit => $p{limit},
        )
    );
}

sub ByUpdateCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit => { type => SCALAR, default => 5 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    return VegGuide::Cursor::UserWithAggregate->new(
        cursor => $schema->UserActivityLog_t->select(
            select => [
                $schema->sqlmaker->COUNT(
                    $schema->UserActivityLog_t->user_activity_log_id_c
                ),
                $schema->UserActivityLog_t->user_id_c
            ],
            where => [
                [
                    $schema->UserActivityLog_t->user_activity_log_type_id_c,
                    'IN',
                    $class->entry_update_activity_type_ids,
                ],
                [
                    $schema->UserActivityLog_t->user_id_c,
                    'NOT IN',
                    $class->users_excluded_from_stats,
                ],
            ],
            group_by => $schema->UserActivityLog_t->user_id_c,
            order_by => [
                $schema->sqlmaker->COUNT(
                    $schema->UserActivityLog_t->user_id_c
                ),
                'DESC',
            ],
            limit => $p{limit},
        )
    );
}

sub ByImageCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit => { type => SCALAR, default => 5 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    return VegGuide::Cursor::UserWithAggregate->new(
        cursor => $schema->VendorImage_t->select(
            select => [
                $schema->sqlmaker->COUNT(
                    $schema->VendorImage_t->vendor_image_id_c
                ),
                $schema->VendorImage_t->user_id_c
            ],
            where => [
                $schema->VendorImage_t->user_id_c,
                'NOT IN',
                $class->users_excluded_from_stats,
            ],
            group_by => $schema->VendorImage_t->user_id_c,
            order_by => [
                $schema->sqlmaker->COUNT( $schema->VendorImage_t->user_id_c ),
                'DESC',
            ],
            limit => $p{limit},
        )
    );
}

sub SendSubscriptionEmails {
    my $class = shift;

    my $users = $class->WithSubscriptions;

    while ( my $user = $users->next ) {
        $user->send_subscription_email;
    }
}

sub WithSubscriptions {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    return $class->cursor(
        $schema->join(
            distinct => $schema->User_t,
            join =>
                [ $schema->tables( 'User', 'UserLocationSubscription' ) ],
        )
    );
}

sub RegionMaintainers {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    return $class->cursor(
        $schema->join(
            distinct => $schema->User_t,
            join =>
                [ $schema->tables( 'User', 'LocationOwner' ) ],
            order_by => [ $schema->User_t->real_name_c ],
        )
    );
}

sub EarliestCreationDate {
    my $class = shift;

    my ($date) = $class->table->function(
        select   => $class->table->creation_datetime_c,
        order_by => [ $class->table->creation_datetime_c, 'ASC' ],
        limit    => 1,
    );

    return DateTime::Format::MySQL->parse_datetime($date)
        ->truncate( to => 'day' );
}

sub CountForDateSpan {
    my $class = shift;
    my %p     = validate(
        @_, {
            start_date => { isa => 'DateTime' },
            end_date   => { isa => 'DateTime' },
        },
    );

    return $class->table->function(
        select => VegGuide::Schema->Connect()
            ->sqlmaker->COUNT( $class->table->user_id_c ),
        where => [
            [
                $class->table->creation_datetime_c, '>=',
                DateTime::Format::MySQL->format_datetime( $p{start_date} )
            ],
            [
                $class->table->creation_datetime_c, '<',
                DateTime::Format::MySQL->format_datetime( $p{end_date} )
            ],
        ],
    );
}

1;
