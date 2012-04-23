package VegGuide::Vendor;

use strict;
use warnings;

use Class::Trait qw( VegGuide::Role::FeedEntry );

use VegGuide::Exceptions qw( auth_error data_validation_error );

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema()->Vendor_t() );

use DateTime;
use DateTime::Format::RFC3339;
use DateTime::Format::MySQL;
use DateTime::Format::Strptime;
use File::Copy;
use File::Find::Rule;
use File::Spec;
use Image::Size ();
use List::Util qw( min sum );
use Math::Round qw( round );
use Storable ();
use URI::FromHash qw( uri );
use VegGuide::Attribute;
use VegGuide::Category;
use VegGuide::Config;
use VegGuide::Cuisine;
use VegGuide::Cursor::DuplicateVendors;
use VegGuide::Cursor::VendorByAggregate;
use VegGuide::Cursor::VendorWithAggregate;
use VegGuide::VendorComment;
use VegGuide::VendorSource;
use VegGuide::Geocoder;
use VegGuide::GreatCircle qw( distance_between_points earth_radius );
use VegGuide::Location;
use VegGuide::PaymentOption;
use VegGuide::PriceRange;
use VegGuide::SiteURI qw( entry_uri region_uri );
use VegGuide::Util qw( string_is_empty troolean clean_text );
use VegGuide::VendorImage;
use VegGuide::VendorRating;
use VegGuide::VendorSuggestion;
use WebService::StreetMapLink;

use VegGuide::Validate
    qw( validate validate_with validate_pos UNDEF SCALAR BOOLEAN ARRAYREF HASHREF
    SCALAR_TYPE );

my $WeightedRatingMinCount = 2;

sub _new_row {
    my $class = shift;
    my %p     = validate_with(
        params => \@_,
        spec   => {
            name => { type => SCALAR, optional => 1 },
        },
        allow_extra => 1,
    );

    my $schema = VegGuide::Schema->Connect();

    my @where;

    if ( $p{name} && $p{canonical_address} ) {
        push @where,
            (
            [ $schema->Vendor_t()->name_c(), '=', $p{name} ],
            [
                $schema->Vendor_t()->canonical_address_c(), '=',
                $p{canonical_address}
            ],
            );
    }
    elsif ( defined $p{external_unique_id} && $p{vendor_source_id} ) {
        push @where,
            (
            [
                $schema->Vendor_t()->external_unique_id_c(), '=',
                $p{external_unique_id}
            ],
            [
                $schema->Vendor_t()->vendor_source_id_c(), '=',
                $p{vendor_source_id}
            ],
            );
    }
    elsif ( $p{name} && scalar keys %p == 1 ) {
        push @where, [ $schema->Vendor_t->name_c, '=', $p{name} ];

    }

    return $schema->Vendor_t->one_row( where => \@where )
        if @where;

    return;
}

my @Columns = __PACKAGE__->columns;

sub create {
    my $class = shift;
    my %p     = @_;

    my @errors;

    my $category_ids = delete $p{category_id}
        or push @errors, 'An entry must have at least one category';

    my $cuisine_ids = delete $p{cuisine_id};

    my $organization_category_id
        = VegGuide::Category->Organization->category_id;

    my $payment_option_ids = delete $p{payment_option_id};

    my $attribute_ids = delete $p{attribute_id};

    $p{home_page} = VegGuide::Util::normalize_uri( $p{home_page} )
        unless string_is_empty( $p{home_page} );

    $p{neighborhood} = $p{new_neighborhood}
        unless string_is_empty( $p{new_neighborhood} );

    delete $p{new_neighborhood};

    $p{localized_neighborhood} = $p{new_localized_neighborhood}
        unless string_is_empty( $p{new_localized_neighborhood} );

    delete $p{new_localized_neighborhood};

    for my $c ( map { $_->name() }
        grep { $_->is_character() || $_->is_blob() } @Columns ) {
        clean_text( $p{$c} )
            if exists $p{$c};
    }

    foreach my $c ( map { $_->name } grep { !$_->nullable } @Columns ) {
        my $nice = ucfirst join ' ', split /_/, $c;
        push @errors, "$nice is required"
            if exists $p{$c} && string_is_empty( $p{$c} );
    }

    data_validation_error error => "One or more data validation errors",
        errors                  => \@errors
        if @errors;

    $p{sortable_name} = VegGuide::Vendor->MakeSortableName( $p{name} );

    my $schema = VegGuide::Schema->Connect();

    $schema->begin_work;

    my $vendor;
    eval {
        $vendor = $class->SUPER::create(
            creation_datetime      => $schema->sqlmaker->NOW(),
            last_modified_datetime => $schema->sqlmaker->NOW(),
            %p,
        );

        $vendor->update_geocode_info();

        foreach my $id ( ref $category_ids ? @$category_ids : $category_ids )
        {
            $schema->VendorCategory_t->insert(
                values => {
                    category_id => $id,
                    vendor_id   => $vendor->vendor_id,
                },
            );
        }

        if ( $payment_option_ids && !$p{is_cash_only} ) {
            foreach my $id (
                ref $payment_option_ids
                ? @$payment_option_ids
                : $payment_option_ids ) {
                $schema->VendorPaymentOption_t->insert(
                    values => {
                        payment_option_id => $id,
                        vendor_id         => $vendor->vendor_id,
                    },
                );
            }
        }

        foreach my $id ( $class->_normalize_cuisines($cuisine_ids) ) {
            $schema->VendorCuisine_t->insert(
                values => {
                    cuisine_id => $id,
                    vendor_id  => $vendor->vendor_id,
                }
            );
        }

        if ($attribute_ids) {
            foreach my $id (
                ref $attribute_ids ? @$attribute_ids : $attribute_ids ) {
                $schema->VendorAttribute_t->insert(
                    values => {
                        attribute_id => $id,
                        vendor_id    => $vendor->vendor_id,
                    },
                );
            }
        }

        $vendor->update( veg_level => 0, skip_log => 1 )
            if $p{veg_level} && $vendor->is_organization;

        my $user = VegGuide::User->new( user_id => $p{user_id} );
        $user->insert_activity_log(
            type      => 'add vendor',
            vendor_id => $vendor->vendor_id,
        );

        $schema->commit;
    };

    if ( my $e = $@ ) {
        eval { $schema->rollback };

        die $e;
    }

    return $vendor;
}

{

    my %skip = (
        map { $_ => 1 }
            qw( address1 address2 city region
            neighborhood
            postal_code phone directions
            localized_address1 localized_address2
            localized_city localized_region
            localized_neighborhood
            allows_smoking
            accepts_reservations
            is_wheelchair_accessible
            creation_datetime
            last_modified_datetime
            user_id vendor_id
            )
    );

    sub clone {
        my $self = shift;

        return VegGuide::Vendor->potential(
            map { $_ => $self->select($_) }
            grep { !$skip{$_} }
            map  { $_->name } VegGuide::Vendor->columns()
        );
    }
}

{
    my $Parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d',
        on_error => 'croak' );

    sub update {
        my $self = shift;
        my %p    = @_;

        my @errors;

        my $user          = delete $p{user};
        my $is_suggestion = delete $p{is_suggestion};
        my $skip_log      = delete $p{skip_log};

        $p{home_page} = VegGuide::Util::normalize_uri( $p{home_page} )
            if defined $p{home_page};

        $p{neighborhood} = $p{new_neighborhood}
            if defined $p{new_neighborhood} && length $p{new_neighborhood};

        delete $p{new_neighborhood};

        $p{localized_neighborhood} = $p{new_localized_neighborhood}
            if defined $p{new_localized_neighborhood}
                && length $p{new_localized_neighborhood};

        delete $p{new_localized_neighborhood};

        my $address1 = exists $p{address1} ? $p{address1} : $self->address1;
        my $city     = exists $p{city}     ? $p{city}     : $self->city;
        my $postal_code
            = exists $p{postal_code} ? $p{postal_code} : $self->postal_code;

        for my $c ( map { $_->name() }
            grep { $_->is_character() || $_->is_blob() } @Columns ) {
            clean_text( $p{$c} )
                if exists $p{$c};
        }

        foreach my $c ( map { $_->name } grep { !$_->nullable } @Columns ) {
            my $nice = ucfirst join ' ', split /_/, $c;
            push @errors, "$nice is required"
                if exists $p{$c} && !defined $p{$c};
        }

        if ( $p{close_date} ) {
            eval { $Parser->parse_datetime( $p{close_date} ) };

            push @errors, 'Invalid close date.'
                if $@;
        }

        data_validation_error error => "One or more data validation errors",
            errors                  => \@errors
            if @errors;

        if ( exists $p{name} ) {
            $p{sortable_name}
                = VegGuide::Vendor->MakeSortableName( $p{name} );
        }

        my $schema = VegGuide::Schema->Connect();

        $schema->begin_work;

        eval {
            if ( $p{category_id} ) {
                $_->delete foreach $schema->VendorCategory_t->rows_where(
                    where => [
                        $schema->VendorCategory_t->vendor_id_c,
                        '=', $self->vendor_id
                    ],
                )->all_rows;

                my $category_ids = delete $p{category_id};

                foreach my $id (
                    ref $category_ids ? @$category_ids : $category_ids ) {
                    $schema->VendorCategory_t->insert(
                        values => {
                            category_id => $id,
                            vendor_id   => $self->vendor_id,
                        },
                    );
                }
            }

            delete $p{payment_option_id} if $p{is_cash_only};
            if ( $p{payment_option_id} ) {
                $_->delete foreach $schema->VendorPaymentOption_t->rows_where(
                    where => [
                        $schema->VendorPaymentOption_t->vendor_id_c,
                        '=', $self->vendor_id
                    ],
                )->all_rows;

                my $payment_option_ids = delete $p{payment_option_id};

                foreach my $id (
                    ref $payment_option_ids
                    ? @$payment_option_ids
                    : $payment_option_ids ) {
                    $schema->VendorPaymentOption_t->insert(
                        values => {
                            payment_option_id => $id,
                            vendor_id         => $self->vendor_id,
                        },
                    );
                }
            }

            if ( $p{cuisine_id} ) {
                $_->delete foreach $schema->VendorCuisine_t->rows_where(
                    where => [
                        $schema->VendorCuisine_t->vendor_id_c,
                        '=', $self->vendor_id
                    ],
                )->all_rows;

                my $cuisine_ids = delete $p{cuisine_id};

                foreach my $id ( $self->_normalize_cuisines($cuisine_ids) ) {
                    $schema->VendorCuisine_t->insert(
                        values => {
                            cuisine_id => $id,
                            vendor_id  => $self->vendor_id,
                        }
                    );
                }
            }

            if ( $p{attribute_id} ) {
                $_->delete foreach $schema->VendorAttribute_t->rows_where(
                    where => [
                        $schema->VendorAttribute_t->vendor_id_c,
                        '=', $self->vendor_id
                    ],
                )->all_rows;

                my $attribute_ids = delete $p{attribute_id};

                foreach my $id (
                    ref $attribute_ids ? @$attribute_ids : $attribute_ids ) {
                    $schema->VendorAttribute_t->insert(
                        values => {
                            attribute_id => $id,
                            vendor_id    => $self->vendor_id,
                        },
                    );
                }
            }

            $self->SUPER::update(
                last_modified_datetime => $schema->sqlmaker->NOW,
                %p,
            );

            $self->SUPER::update( veg_level => 0 )
                if $p{veg_level} && $self->is_organization;

            $self->update_geocode_info();

            $user->insert_activity_log(
                type      => 'update vendor',
                vendor_id => $self->vendor_id,
            ) unless $is_suggestion || $skip_log;

            $schema->commit;
        };

        if ( my $e = $@ ) {
            eval { $schema->rollback };

            die $e;
        }
    }
}

sub delete {
    my $self = shift;

    if ( my $source = $self->vendor_source() ) {
        $source->add_excluded_id( $self->external_unique_id() );
    }

    $self->SUPER::delete();
}

# This would be a lot smarter if it was sensitive to the language of
# the region. For example, for French entries, maybe the sortable name
# should remove "Le" and "La", but for English-speaking areas, those
# words _should_ be part of the sorting.
sub MakeSortableName {
    my $class = shift;
    my $name  = shift;

    $name =~ s/^(?:a|the) //i;

    return $name;
}

sub update_last_featured_date {
    my $self = shift;

    $self->SUPER::update(
        last_featured_date => VegGuide::Schema->Connect()->sqlmaker->NOW );
}

sub is_closed { defined $_[0]->close_date() }

sub save_core_suggestion {
    my $self = shift;
    my %p    = validate(
        @_, {
            suggestion => { type => HASHREF },
            comment    => { type => UNDEF | SCALAR, default => undef },
            user_wants_notification => { type => BOOLEAN, default => 0 },
            user                    => { isa  => 'VegGuide::User' },
        },
    );

    $p{suggestion}{neighborhood} = $p{suggestion}{new_neighborhood}
        if defined $p{suggestion}{new_neighborhood}
            && length $p{suggestion}{new_neighborhood};

    delete $p{suggestion}{new_neighborhood};

    $p{suggestion}{localized_neighborhood}
        = $p{suggestion}{new_localized_neighborhood}
        if defined $p{suggestion}{new_localized_neighborhood}
            && length $p{suggestion}{new_localized_neighborhood};

    delete $p{suggestion}{new_localized_neighborhood};

    my %suggestion;

    $p{suggestion}{home_page}
        = VegGuide::Util::normalize_uri( $p{suggestion}{home_page} )
        if defined $p{suggestion}{home_page};

    foreach my $c ( map { $_->name } grep { !$_->nullable } @Columns ) {
        my $nice = ucfirst join ' ', split /_/, $c;
        data_validation_error "$nice is required"
            if exists $p{suggestion}{$c} && !defined $p{suggestion}{$c};
    }

    my %skip = (
        map { $_ => 1 }
            qw( user_id location_id sortable_name
            creation_datetime
            last_modified_datetime last_featured_date
            canonical_address longitude latitude )
    );

    foreach my $c (
        grep { exists $p{suggestion}{$_} }
        grep { !$skip{$_} }
        map  { $_->name }
        grep { !$_->is_primary_key } @Columns
        ) {
        my $current = $self->$c();

        $suggestion{$c} = $p{suggestion}{$c}
            unless (
            (
                   defined $p{suggestion}{$c}
                && defined $current
                && $p{suggestion}{$c} eq $current
            )
            || ( !defined $p{suggestion}{$c} && !defined $current )
            );
    }

    my @c = $self->_normalize_cuisines( $p{suggestion}{cuisine_id} );
    $p{suggestion}{cuisine_id} = \@c if @c;

    foreach
        my $key (qw( category_id payment_option_id cuisine_id attribute_id ))
    {
        next unless exists $p{suggestion}{$key};
        next if $p{suggestion}{is_cash_only} && $key eq 'payment_option_id';

        my $ids = (
            ref $p{suggestion}{$key}
            ? [ sort @{ $p{suggestion}{$key} } ]
            : [ $p{suggestion}{$key} ]
        );

        my $meth = $key . 's';
        unless (
            VegGuide::Util::arrays_match( $ids, [ sort $self->$meth() ] ) ) {
            $suggestion{$key} = $p{suggestion}{$key};
        }
    }

    return unless keys %suggestion;

    my $schema = VegGuide::Schema->Connect();

    $schema->begin_work;

    my $suggestion;
    eval {
        $suggestion = $schema->VendorSuggestion_t->insert(
            values => {
                type                    => 'core',
                suggestion              => Storable::nfreeze( \%suggestion ),
                comment                 => $p{comment},
                user_wants_notification => $p{user_wants_notification},
                creation_datetime       => $schema->sqlmaker->NOW(),
                vendor_id               => $self->vendor_id,
                user_id                 => $p{user}->user_id,
            },
        );

        $p{user}->insert_activity_log(
            type      => 'suggest a change',
            vendor_id => $self->vendor_id,
            comment   => 'core data',
        );

        $schema->commit;
    };

    if ( my $e = $@ ) {
        eval { $schema->rollback };

        die $e;
    }

    return $suggestion;
}

sub save_hours_suggestion {
    my $self = shift;
    my %p    = validate(
        @_, {
            hours   => { type => ARRAYREF },
            comment => { type => UNDEF | SCALAR, default => undef },
            user_wants_notification => { type => BOOLEAN, default => 0 },
            user                    => { isa  => 'VegGuide::User' },
        },
    );

    $self->_validate_hour_sets( $p{hours} );

    my $schema = VegGuide::Schema->Connect();

    $schema->begin_work;

    my $suggestion;

    eval {
        $suggestion = $schema->VendorSuggestion_t->insert(
            values => {
                type                    => 'hours',
                suggestion              => Storable::nfreeze( $p{hours} ),
                comment                 => $p{comment},
                user_wants_notification => $p{user_wants_notification},
                creation_datetime       => $schema->sqlmaker->NOW(),
                vendor_id               => $self->vendor_id,
                user_id                 => $p{user}->user_id,
            },
        );

        $p{user}->insert_activity_log(
            type      => 'suggest a change',
            vendor_id => $self->vendor_id,
            comment   => 'hours',
        );

        $schema->commit;
    };

    if ( my $e = $@ ) {
        eval { $schema->rollback };

        die $e;
    }

    return $suggestion;
}

sub category_ids {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    $self->{category_ids} ||= [
        $schema->function(
            select => $schema->VendorCategory_t()->category_id_c(),
            join   => [ $schema->tables( 'VendorCategory', 'Category' ) ],
            where  => [
                $schema->VendorCategory_t()->vendor_id_c(), '=',
                $self->vendor_id()
            ],
            order_by => [ $schema->Category_t()->display_order_c(), 'ASC' ],
        )
    ];

    return @{ $self->{category_ids} };
}

# for fill in form
sub category_id { [ $_[0]->category_ids ] }

sub payment_option_ids {
    my $schema = VegGuide::Schema->Connect();

    return shift->_id_list(
        $schema->VendorPaymentOption_t,
        $schema->VendorPaymentOption_t->payment_option_id_c,
    );
}

# for fill in form
sub payment_option_id { [ $_[0]->payment_option_ids ] }

sub cuisine_ids {
    my $schema = VegGuide::Schema->Connect();

    return shift->_id_list(
        $schema->VendorCuisine_t,
        $schema->VendorCuisine_t->cuisine_id_c,
    );
}

# for fill in form
sub cuisine_id { [ $_[0]->cuisine_ids ] }

sub _id_list {
    my $self   = shift;
    my $table  = shift;
    my $column = shift;

    return $table->function(
        select => $column,
        where =>
            [ $table->vendor_id_c, '=', $self->vendor_id ],
    );
}

sub attributes {
    my $self = shift;

    $self->_get_attributes;

    return @{ $self->{attributes} };
}

sub attribute_ids {
    return map { $_->select('attribute_id') } $_[0]->attributes;
}

# for fill in form
sub attribute_id { [ $_[0]->attribute_ids ] }

sub _get_attributes {
    my $self = shift;

    return if $self->{attributes};

    my $schema = VegGuide::Schema->Connect();

    $self->{attributes} = [
        $self->cursor(
            $schema->join(
                select => $schema->Attribute_t,
                join => [ $schema->tables( 'Attribute', 'VendorAttribute' ) ],
                where => [
                    $schema->VendorAttribute_t->vendor_id_c, '=',
                    $self->vendor_id
                ],
                order_by => $schema->Attribute_t->name_c,
            )
            )->all()
    ];
}

{
    my %char_cols
        = map { $_->name => 1 }
        grep { $_->is_character || $_->is_blob } @Columns;

    my %num_cols
        = map { $_->name => 1 }
        grep { $_->is_numeric } @Columns;

    my %tri_state_cols
        = map { $_->name => 1 }
        grep {
               $_->type eq 'TINYINT'
            && $_->length
            && $_->length == 1
            && $_->nullable
        } @Columns;

    # for fill in form - because it ignores fields where the value is undef
    sub is_special_case_form_param { $tri_state_cols{ $_[1] } }
}

# when a child and ancestor(s) are both present, we remove all the
# ancestors, leaving only the most specific children
sub _normalize_cuisines {
    my $class = shift;

    return unless defined $_[0];

    my %ids = map { $_ => 1 } ref $_[0] ? @{ $_[0] } : $_[0];

    foreach my $id ( keys %ids ) {
        delete @ids{ $class->_cuisine_ancestors($id) };
    }

    return keys %ids;
}

sub _cuisine_ancestors {
    my $self = shift;
    my $id   = shift;

    my $schema = VegGuide::Schema->Connect();

    my @ids;
    while (
        $id = $schema->Cuisine_t->function(
            select => $schema->Cuisine_t->parent_cuisine_id_c,
            where  => [ $schema->Cuisine_t->cuisine_id_c, '=', $id ]
        )
        ) {
        push @ids, $id;
    }

    return @ids;
}

sub accepts_checks {
    my $self = shift;

    return unless $self->is_live;

    my $schema = VegGuide::Schema->Connect();

    return $schema->function(
        select => $schema->VendorPaymentOption_t->vendor_id_c,
        join => [ $schema->tables( 'VendorPaymentOption', 'PaymentOption' ) ],
        where => [
            [
                $schema->VendorPaymentOption_t->vendor_id_c,
                '=', $self->vendor_id
            ],
            [
                $schema->PaymentOption_t->name_c,
                '=', 'Check'
            ],
        ],
    );
}

sub accepted_credit_cards {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return (
        map { VegGuide::PaymentOption->new( object => $_ ) }
            $self->row_object->payment_options(
            where => [ $schema->PaymentOption_t->name_c, '!=', 'Check' ],
            order_by =>
                [ $schema->PaymentOption_t->name_c, 'ASC' ],
            )->all_rows
    );
}

sub categories {
    my $self = shift;

    return VegGuide::Category->Restaurant
        unless $self->is_live;

    return @{ $self->{categories} }
        if exists $self->{categories};

    $self->{categories}
        = [ map { VegGuide::Category->new( category_id => $_ ) }
            $self->category_ids ];

    return @{ $self->{categories} };
}

sub primary_category {
    my $self = shift;

    return ( $self->categories() )[0];
}

sub payment_options {
    my $self = shift;

    return unless $self->is_live;

    my $schema = VegGuide::Schema->Connect();

    return
        map { VegGuide::PaymentOption->new( object => $_ ) }
        $self->row_object->payment_options(
        order_by => [ $schema->PaymentOption_t->name_c, 'ASC' ],
        )->all_rows;
}

sub available_payment_options {
    my $schema = VegGuide::Schema->Connect();

    return shift->cursor(
        $schema->PaymentOption_t->all_rows(
            order_by => [ $schema->PaymentOption_t->name_c, 'ASC' ],
        )
    );
}

sub cuisines {
    my $self = shift;

    return unless $self->is_live;

    return
        map { VegGuide::Cuisine->new( cuisine_id => $_ ) } $self->cuisine_ids;
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

sub review_count {
    my $self = shift;

    return $self->{__review_count__}
        if exists $self->{__review_count__};

    my $schema = VegGuide::Schema->Connect();

    return $self->{__review_count__} = $schema->VendorComment_t->row_count(
        where => [
            $schema->VendorComment_t->vendor_id_c,
            '=', $self->vendor_id
        ],
    );
}

sub comment_by_user {
    my $self = shift;
    my $user = shift;

    return VegGuide::VendorComment->new(
        user_id   => $user->user_id,
        vendor_id => $self->vendor_id,
    );
}

sub comments {
    my $self = shift;
    my %p    = validate(
        @_, {
            order_by =>
                { type => SCALAR, default => 'last_modified_datetime' },
            sort_order => { type => SCALAR, default  => 'DESC' },
            limit      => { type => SCALAR, optional => 1 },
        },
    );

    my %limit;
    $limit{limit} = $p{limit} if $p{limit};

    my $schema = VegGuide::Schema->Connect();

    return $self->cursor(
        $schema->join(
            join  => [ $schema->tables( 'VendorComment', 'User' ) ],
            where => [
                $schema->VendorComment_t->vendor_id_c, '=', $self->vendor_id
            ],
            order_by => [
                $schema->VendorComment_t->column( $p{order_by} ),
                $p{sort_order}
            ],
            %limit,
        )
    );
}

sub add_or_update_comment {
    my $self = shift;
    my %p    = validate(
        @_, {
            user                => { isa     => 'VegGuide::User' },
            comment             => { type    => UNDEF | SCALAR },
            calling_user        => { isa     => 'VegGuide::User' },
            force_last_modified => { default => 0 },
        },
    );

    data_validation_error "Comments must have content."
        unless defined $p{comment} && length $p{comment};

    if ( $p{user}->user_id != $p{calling_user}->user_id ) {
        auth_error "Cannot edit other user's comments"
            unless $p{calling_user}->is_admin();
    }

    my $schema = VegGuide::Schema->Connect();

    my $comment;
    if ( $comment = $self->comment_by_user( $p{user} ) ) {
        my %last_modified = (
            $p{user}->user_id == $p{calling_user}->user_id
                || $p{force_last_modified}
            ? ( last_modified_datetime => $schema->sqlmaker->NOW() )
            : ()
        );

        $comment->update(
            comment => $p{comment},
            %last_modified,
        );

        if ( $p{user}->user_id == $p{calling_user}->user_id ) {
            $p{user}->insert_activity_log(
                type      => 'update review',
                vendor_id => $self->vendor_id,
            );
        }
    }
    else {
        $comment = VegGuide::VendorComment->create(
            user_id   => $p{user}->user_id,
            vendor_id => $self->vendor_id,
            comment   => $p{comment},
            last_modified_datetime =>
                $schema->sqlmaker->NOW(),
        );

        $p{user}->insert_activity_log(
            type      => 'add review',
            vendor_id => $self->vendor_id,
        );
    }

    return $comment;
}

{
    my $AverageRating;

    sub AverageRating {
        my $class = shift;

        unless ( defined $AverageRating ) {
            my $schema = VegGuide::Schema->Connect();

            my $vr = $schema->VendorRating_t();

            $AverageRating = $vr->function(
                select => $schema->sqlmaker()->AVG( $vr->rating_c() ) );
        }

        return $AverageRating;
    }

    sub ClearCache {
        undef $AverageRating;
    }

    sub add_or_update_rating {
        my $self = shift;
        my %p    = validate(
            @_, {
                user => { isa => 'VegGuide::User' },

                rating => {
                    type      => SCALAR,
                    callbacks => {
                        '1 through 5' =>
                            sub { defined $_[0] && $_[0] >= 1 && $_[0] <= 5 },
                    },
                },
            },
        );

        my $schema = VegGuide::Schema->Connect();

        my $rating;
        if (
            $rating = $schema->VendorRating_t->one_row(
                where => [
                    [
                        $schema->VendorRating_t->user_id_c, '=',
                        $p{user}->user_id
                    ],
                    [
                        $schema->VendorRating_t->vendor_id_c, '=',
                        $self->vendor_id
                    ],
                ],
            )
            ) {
            $rating->update(
                rating          => $p{rating},
                rating_datetime => $schema->sqlmaker()->NOW(),
            );
        }
        else {
            $rating = $schema->VendorRating_t->insert(
                values => {
                    user_id         => $p{user}->user_id,
                    vendor_id       => $self->vendor_id,
                    rating          => $p{rating},
                    rating_datetime => $schema->sqlmaker()->NOW(),
                },
            );
        }

        undef $AverageRating;
    }

    sub delete_rating {
        my $self = shift;
        my %p    = validate(
            @_, {
                user => { isa => 'VegGuide::User' },
            },
        );

        my $schema = VegGuide::Schema->Connect();

        my $rating;
        if (
            $rating = $schema->VendorRating_t->one_row(
                where => [
                    [
                        $schema->VendorRating_t->user_id_c, '=',
                        $p{user}->user_id
                    ],
                    [
                        $schema->VendorRating_t->vendor_id_c, '=',
                        $self->vendor_id
                    ],
                ],
            )
            ) {
            $rating->delete();
        }

        undef $AverageRating;
    }
}

sub rating_from_user {
    my $self = shift;
    my $user = shift;

    return 0 unless $self->is_live;

    my $schema = VegGuide::Schema->Connect();

    my $rating = $schema->VendorRating_t->function(
        select => $schema->VendorRating_t->rating_c,
        where  => [
            [ $schema->VendorRating_t->vendor_id_c, '=', $self->vendor_id ],
            [ $schema->VendorRating_t->user_id_c,   '=', $user->user_id ],
        ],
    );

    return unless defined $rating;

    return $rating;
}

=pod

DROP FUNCTION IF EXISTS WEIGHTED_RATING;

delimiter //

CREATE FUNCTION
  WEIGHTED_RATING (vendor_id INTEGER, min INTEGER, overall_mean FLOAT)
                  RETURNS FLOAT
  DETERMINISTIC
  READS SQL DATA
BEGIN
  DECLARE v_mean  FLOAT;
  DECLARE v_count FLOAT;
  DECLARE l_mean  FLOAT;

  SELECT AVG(rating), COUNT(rating) INTO v_mean, v_count
    FROM VendorRating
   WHERE VendorRating.vendor_id = vendor_id;

  IF v_count = 0 THEN
    RETURN 0.0;
  END IF;

  RETURN ( v_count / ( v_count + min ) ) * v_mean + ( min / ( v_count + min ) ) * overall_mean;
END;

//

delimiter ;

=cut

BEGIN {
    Alzabo::SQLMaker::make_function(
        function => 'WEIGHTED_RATING',
        min      => 3,
        max      => 3,
        groups   => ['udf'],
    );
}

sub weighted_rating_and_count {
    my $self = shift;

    $self->{weighted_rating_and_count}
        ||= $self->_weighted_rating_and_count();

    return @{ $self->{weighted_rating_and_count} };
}

sub _weighted_rating_and_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my $count = $self->rating_count();

    return [ 0, 0 ] unless $count;

    return [ $self->weighted_rating(), $count ];
}

sub weighted_rating {
    my $self = shift;

    return $self->{weighted_rating}
        if defined $self->{weighted_rating};

    my $schema = VegGuide::Schema->Connect();

    my $rating = $schema->sqlmaker()->ROUND(
        WEIGHTED_RATING(
            $self->vendor_id(),
            $WeightedRatingMinCount,
            $self->AverageRating(),
        ),
        1
    );

    return $self->{weighted_rating} = $schema->Vendor_t()->function(
        select => $rating,
        where =>
            [ $schema->Vendor_t()->vendor_id_c(), '=', $self->vendor_id() ],
    );
}

sub WeightedRating {
    my $class   = shift;
    my $average = shift;
    my $count   = shift;

    my $cavg = $class->AverageRating();

    return sprintf(
        '%.1f',
        ( $count / ( $count + $WeightedRatingMinCount ) ) * $average + (
            $WeightedRatingMinCount / ( $count + $WeightedRatingMinCount )
            ) * $class->AverageRating()
    );
}

sub WeightedRatingMinCount {
    return $WeightedRatingMinCount;
}

sub rating_count {
    my $self = shift;

    return $self->{__rating_count__}
        if exists $self->{__rating_count__};

    my $schema = VegGuide::Schema->Connect();

    return $self->{__rating_count__} = $schema->VendorRating_t->row_count(
        where =>
            [ $schema->VendorRating_t->vendor_id_c, '=', $self->vendor_id ],
    );
}

sub ratings_without_review_count {
    my $self = shift;

    return $self->{__ratings_without_review_count__}
        if exists $self->{__ratings_without_review_count__};

    my $schema = VegGuide::Schema->Connect();

    my @where
        = [ $schema->VendorRating_t->vendor_id_c, '=', $self->vendor_id ];

    push @where,
        [
        $schema->VendorRating_t->user_id_c, 'NOT IN',
        $self->_ratings_without_reviews_subselect()
        ];

    return $self->{__ratings_without_review_count__} = $schema->row_count(
        join  => [ $schema->tables( 'VendorRating', 'User' ) ],
        where => \@where,
    );
}

sub ratings_without_reviews {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my @where
        = [ $schema->VendorRating_t->vendor_id_c, '=', $self->vendor_id ];

    push @where,
        [
        $schema->VendorRating_t->user_id_c, 'NOT IN',
        $self->_ratings_without_reviews_subselect()
        ];

    return $self->cursor(
        $schema->join(
            join     => [ $schema->tables( 'VendorRating', 'User' ) ],
            where    => \@where,
            order_by => [
                $schema->VendorRating_t->rating_c, 'DESC',
                $schema->User_t->real_name_c,      'ASC',
            ],
        )
    );
}

sub _ratings_without_reviews_subselect {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->sqlmaker()
        ->select( $schema->VendorComment_t()->user_id_c() )
        ->from( $schema->VendorComment_t() )
        ->where( $schema->VendorComment_t()->vendor_id_c(), '=',
        $self->vendor_id() );
}

sub price_range {
    my $self = shift;

    if ( $self->price_range_id ) {
        return VegGuide::PriceRange->new(
            price_range_id => $self->price_range_id );
    }
    else {
        return VegGuide::PriceRange->Average;
    }
}

sub hour_sets_by_day {
    my $self = shift;

    return @{ $self->{hour_sets} } if $self->{hour_sets};

    my $schema = VegGuide::Schema->Connect();

    my $hours = $self->row_object->hours(
        order_by => [
            $schema->VendorHours_t->day_c,         'ASC',
            $schema->VendorHours_t->open_minute_c, 'ASC',
        ],
    );

    my @sets;
    while ( my $set = $hours->next ) {
        my %times = (
            open_minute  => $set->select('open_minute'),
            close_minute => $set->select('close_minute'),
        );

        push @{ $sets[ $set->select('day') ] }, \%times;
    }

    $self->{hour_sets} = \@sets;

    return @sets;
}

sub hour_sets_by_day_as_time_ranges {
    my $self = shift;

    my @raw = $self->hour_sets_by_day();
    return unless @raw;

    my @sets;
    for my $day ( 0 .. $#raw ) {
        if (   $raw[$day][0]{open_minute}
            && $raw[$day][0]{open_minute} == -1 ) {
            $sets[$day] = [ { is_closed => 1 } ];
        }
        elsif ( $raw[$day] ) {
            for my $set ( @{ $raw[$day] } ) {
                next unless defined $set->{open_minute};

                my $open
                    = VegGuide::Vendor->MinutesToTime( $set->{open_minute} );
                my $close
                    = VegGuide::Vendor->MinutesToTime( $set->{close_minute} );

                my $desc;
                if ( $open eq $close ) {
                    $desc = '24 hours';
                }
                else {
                    $desc = "$open to $close";
                }

                push @{ $sets[$day] }, { hours => $desc };
            }
        }
    }

    return @sets;
}

sub has_hours_info {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorHours_t->row_count(
        where =>
            [ $schema->VendorHours_t->vendor_id_c, '=', $self->vendor_id ],
    );
}

sub hours_are_complete {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my $days_known = $schema->VendorHours_t->function(
        select => $schema->sqlmaker->COUNT(
            $schema->sqlmaker->DISTINCT( $schema->VendorHours_t->day_c )
        ),
        where =>
            [ $schema->VendorHours_t->vendor_id_c, '=', $self->vendor_id ],
    );

    $days_known == 7 ? 1 : 0;
}

sub hours_as_descriptions {
    my $self = shift;

    push @_, sets => [ $self->hour_sets_by_day() ]
        if ref $self && !@_;

    my %p = validate(
        @_, {
            sets => { type => ARRAYREF },
        },
    );

    my @days_abbr = VegGuide::Util::days_abbr();

    my @descriptions;

    my $last_day_changed = 0;
    my @last_hours;
    foreach my $day ( 0 .. 6 ) {
        my @current_hours;
        if ( !$p{sets}->[$day] ) {
            push @current_hours, '?';
        }
        elsif ( $p{sets}->[$day][0]{open_minute} == -1 ) {
            push @current_hours, 'closed';
        }
        else {
            if ( $p{sets}->[$day][0]{open_minute} eq
                $p{sets}->[$day][0]{close_minute} ) {
                push @current_hours, '24 hours';
            }
            else {
                push @current_hours,
                    $self->_set_as_description( $p{sets}->[$day][0] );

                push @current_hours,
                    $self->_set_as_description( $p{sets}->[$day][1] )
                    if $p{sets}->[$day][1];
            }
        }

        my $day_abbr = $days_abbr[$day];

        if ( @last_hours
            && !VegGuide::Util::arrays_match( \@current_hours, \@last_hours )
            ) {
            my $day_desc;
            if ( defined $last_day_changed
                && $last_day_changed != $day - 1 ) {
                $day_desc
                    = "$days_abbr[$last_day_changed] - $days_abbr[$day - 1]";
            }
            else {
                $day_desc = $days_abbr[ $day - 1 ];
            }

            push @descriptions, {
                days  => $day_desc,
                hours => [@last_hours],
                };

            $last_day_changed = $day;
        }

        @last_hours = @current_hours;
    }

    my $day_desc;
    if ( defined $last_day_changed
        && $last_day_changed != 6 ) {
        $day_desc = "$days_abbr[$last_day_changed] - $days_abbr[6]";
    }
    else {
        $day_desc = $days_abbr[6];
    }

    if (@descriptions) {
        push @descriptions, {
            days  => $day_desc,
            hours => \@last_hours,
            };
    }
    else {
        @descriptions = {
            days  => 'Daily',
            hours => \@last_hours,
        };
    }

    return @descriptions;
}

sub _set_as_description {
    my $self        = shift;
    my $set         = shift;
    my $hours_as_24 = shift;

    my $open_time  = VegGuide::Vendor->MinutesToTime( $set->{open_minute} );
    my $close_time = VegGuide::Vendor->MinutesToTime( $set->{close_minute} );

    return $open_time . ' - ' . $close_time;
}

sub MinutesToTime {
    my $class       = shift;
    my $minutes     = shift;
    my $hours_as_24 = shift;

    my $real_hour = int( $minutes / 60 );

    my $hour = $real_hour;
    unless ($hours_as_24) {
        $hour = $hour % 12;
        $hour = 12 if $hour == 0;
    }

    my $minute = $minutes % 60;

    my $time = sprintf( "$hour:%02d", $minute );
    $time .= $real_hour >= 12 ? 'pm' : 'am';

    $time =~ s/:00//;

    return 'noon'     if $time eq '12pm';
    return 'midnight' if $time eq '12am';

    return $time;
}

sub CanonicalHoursRangeDescription {
    my $class     = shift;
    my $range     = shift;
    my $assume_pm = shift;

    my $today = DateTime->today( time_zone => 'UTC' );

    my ( $time1, $time2 ) = split /\s*(?:-|to)\s*/i, $range;

    if ( $time1 =~ /^\s*24/ ) {
        return '24 hours';
    }

    return 'Need both open and close'
        unless defined $time1 && defined $time2;

    my $dt1 = _parse_time( $time1, $assume_pm );
    data_validation_error "First time ($time1) was invalid\n" unless $dt1;

    my $dt2 = _parse_time( $time2, 'assume pm' );
    data_validation_error "Second time ($time2) was invalid" unless $dt2;

    my $desc = _format_time($dt1);
    $desc .= ' to ';
    $desc .= _format_time($dt2);

    $desc .= ' the next day'
        if $dt1 > $dt2 && $dt2->strftime('%H:%M') ne '00:00';

    return $desc;
}

{
    my $FormatWithoutMinutes = '%{hour_12}%P';
    my $FormatWithMinutes    = '%{hour_12}:%M%P';

    sub _format_time {
        my $dt = shift;

        my $time = $dt->strftime(
            $dt->minute() ? $FormatWithMinutes : $FormatWithoutMinutes );

        return 'noon'     if $time eq '12pm';
        return 'midnight' if $time eq '12am';
        return $time;
    }
}

sub HoursRangeToMinutes {
    my $class     = shift;
    my $range     = shift;
    my $assume_pm = shift;

    my ( $time1, $time2 ) = split /\s*(?:-|to)\s*/i, $range;

    if ( $time1 =~ /^\s*24/ ) {
        return { open_minute => 0, close_minute => 0 };
    }

    return 'Need both open and close'
        unless defined $time1 && defined $time2;

    my $dt1 = _parse_time( $time1, $assume_pm );
    return "First time ($time1) was invalid" unless $dt1;

    my $dt2 = _parse_time( $time2, 'assume pm' );
    return "Second time ($time2) was invalid" unless $dt2;

    return {
        open_minute  => ( $dt1->hour() * 60 ) + $dt1->minute(),
        close_minute => ( $dt2->hour() * 60 ) + $dt2->minute(),
    };
}

{

    # The date portion is really irrelevant, it's just being used to
    # format times.
    my $Date = DateTime->today( time_zone => 'UTC' );

    sub _parse_time {
        my $time      = shift;
        my $assume_pm = shift;

        my ( $h, $m );
        if ( $time =~ /noon/i ) {
            $h = 12;
            $m = 0;
        }
        elsif ( $time =~ /midnight/i ) {
            $h = 0;
            $m = 0;
        }
        else {
            my $ampm;
            ( $h, $m, $ampm )
                = $time =~ m{ (\d\d?) (?: [:./] (\d\d) )? \s* (a|p)? }ixsm;
            $m ||= 0;

            return unless defined $h;

            if ( $ampm && lc $ampm eq 'a' && $h == 12 ) {
                $h = 0;
            }

            if ( $ampm && lc $ampm eq 'p' && $h < 12 ) {
                $h += 12;
            }

            if ( !$ampm && $h < 12 && $assume_pm ) {
                $h += 12;
            }
        }

        return eval { $Date->clone()->set( hour => $h, minute => $m ) };
    }
}

sub replace_hours {
    my $self = shift;
    my $sets = shift;

    $self->_validate_hour_sets($sets);

    my $schema = VegGuide::Schema->Connect();

    $schema->begin_work;

    eval {
        my $hours = $self->row_object->hours;
        while ( my $set = $hours->next ) {
            $set->delete;
        }

        foreach my $day ( 0 .. 6 ) {
            next unless $sets->[$day];

            if ( $sets->[$day][0]{open_minute} == -1 ) {
                $schema->VendorHours_t->insert(
                    values => {
                        vendor_id    => $self->vendor_id,
                        day          => $day,
                        open_minute  => -1,
                        close_minute => 0,
                    },
                );

                next;
            }

            $schema->VendorHours_t->insert(
                values => {
                    vendor_id    => $self->vendor_id,
                    day          => $day,
                    open_minute  => $sets->[$day][0]{open_minute},
                    close_minute => $sets->[$day][0]{close_minute},
                },
            );

            next unless $sets->[$day][1];

            $schema->VendorHours_t->insert(
                values => {
                    vendor_id    => $self->vendor_id,
                    day          => $day,
                    open_minute  => $sets->[$day][1]{open_minute},
                    close_minute => $sets->[$day][1]{close_minute},
                },
            );
        }

        $self->SUPER::update(
            last_modified_datetime => $schema->sqlmaker->NOW() );

        $schema->commit;
    };

    if ( my $e = $@ ) {
        eval { $schema->rollback };

        die $e;
    }
}

sub _validate_hour_sets {
    my $self = shift;
    my ($sets) = validate_pos( @_, { type => ARRAYREF } );

    my @days = VegGuide::Util::days();

    foreach my $day ( 0 .. 6 ) {
        next unless $sets->[$day];

        my $first_open  = $sets->[$day][0]{open_minute};
        my $first_close = $sets->[$day][0]{close_minute};

        next if $first_open == -1;

        next unless $sets->[$day][1];

        my $second_open  = $sets->[$day][1]{open_minute};
        my $second_close = $sets->[$day][1]{close_minute};

        my %range1 = map { $_ => 1 } $first_open .. $first_close;
        my %range2 = map { $_ => 1 } $second_open .. $second_close;

        if ( grep { exists $range1{$_} } keys %range2 ) {
            data_validation_error
                "The two sets of hours for $days[$day] overlap.";
        }
    }
}

sub has_address {
    my $self = shift;

    return grep { ! string_is_empty($_) } $self->address_pieces();
}

sub address_pieces {
    my $self = shift;

    my $meth = '_address_pieces_' . $self->location->address_format;

    $self->$meth();
}

sub _address_pieces_standard {
    return ( grep {defined} $_[0]->address1, $_[0]->address2,
        $_[0]->city_region_postal_code );
}

sub _address_pieces_Hungarian {
    return (
        join ', ',
        grep {defined}
            $_[0]->postal_code, $_[0]->city, $_[0]->region, $_[0]->address1,
        $_[0]->address2
    );
}

sub address_hash {
    my $self = shift;

    return {
        street1     => $self->address1(),
        street2     => $self->address2(),
        city        => $self->city(),
        region      => $self->region(),
        postal_code => $self->postal_code(),
    };
}

sub localized_address_hash {
    my $self = shift;

    return {
        street1     => $self->localized_address1(),
        street2     => $self->localized_address2(),
        city        => $self->localized_city(),
        region      => $self->localized_region(),
        postal_code => $self->postal_code(),
    };
}

sub city_region_postal_code {
    my $self = shift;

    my ( $city, $region, $postal_code )
        = ( $self->city, $self->region, $self->postal_code );

    my $c_r_pc;
    $c_r_pc = $city if defined $city;
    $c_r_pc .= ', ' if defined $city && defined $region;
    $c_r_pc .= $region if defined $region;
    $c_r_pc .= "  $postal_code" if defined $postal_code;

    return $c_r_pc;
}

sub map_uri {
    my $self = shift;

    return unless $self->location()->has_addresses();

    my $geocoder = $self->_geocoder();
    if ( $geocoder && !string_is_empty( $self->canonical_address() ) ) {
        return uri(
            scheme => 'http',
            host   => $geocoder->hostname(),
            path   => '/maps',
            query =>
                { q => Encode::encode( 'utf8', $self->canonical_address() ) },
        );
    }
    else {
        my $map_link = WebService::StreetMapLink->new(
            country     => $self->location()->country(),
            address     => $self->address1(),
            city        => $self->city(),
            state       => $self->region(),
            postal_code => $self->postal_code(),
        );

        return $map_link->uri() if $map_link;
    }
}

sub update_geocode_info {
    my $self = shift;

    my $geocoder = $self->_geocoder()
        or return;

    my %p;
    for my $meth (
        qw( address1 localized_address1
        city localized_city
        region localized_region
        postal_code )
        ) {
        my $val = $self->$meth();
        $p{$meth} = $val
            if defined $val;
    }

    my $result = $geocoder->geocode(%p);

    return unless $result;

    $self->SUPER::update(
        latitude          => $result->latitude(),
        longitude         => $result->longitude(),
        canonical_address => $result->canonical_address(),
    );
}

sub _geocoder {
    my $self = shift;

    my $country = $self->location()->country();

    return VegGuide::Geocoder->new( country => $country );
}

{
    my %Desc = (
        5 => 'Vegan',
        4 => 'Vegetarian',
        3 => 'Vegetarian (But Not Vegan-Friendly)',
        2 => 'Vegan-Friendly',
        1 => 'Vegetarian-Friendly',
        0 => 'Not Veg-Friendly',
    );

    sub VegLevelDescription {
        return $Desc{ $_[1] };
    }
}

{

    # This is duplicated in the JS code and has to stay in sync!
    my @Desc = qw( terrible
        fair
        good
        great
        excellent
    );

    sub RatingDescription {
        return $Desc[ $_[1] - 1 ];
    }
}

{
    my $spec = {
        latitude  => SCALAR_TYPE,
        longitude => SCALAR_TYPE,
        unit      => SCALAR_TYPE( regex => qr/^(?:mile|km)$/ ),
    };

    sub distance_from {
        my $self = shift;
        my %p = validate( @_, $spec );

        return unless $self->latitude();

        return distance_between_points(
            latitude1  => $self->latitude(),
            longitude1 => $self->longitude(),
            latitude2  => $p{latitude},
            longitude2 => $p{longitude},
            unit       => $p{unit},
        );
    }
}

sub veg_description {
    $_[0]->VegLevelDescription( $_[0]->veg_level );
}

sub is_vegan {
    $_[0]->veg_level == 5 ? 1 : 0;
}

sub is_vegetarian {
    $_[0]->veg_level >= 3 ? 1 : 0;
}

sub is_vegan_friendly {
    $_[0]->veg_level == 2 || $_[0]->veg_level >= 4 ? 1 : 0;
}

sub is_vegetarian_friendly {
    $_[0]->veg_level >= 1 ? 1 : 0;
}

sub vegan_level {
    my $self = shift;

    return (
          $self->is_vegan          ? 'vegan'
        : $self->is_vegan_friendly ? 'vegan-friendly'
        : 'neither'
    );
}

sub vegetarian_level {
    my $self = shift;

    return (
          $self->is_vegetarian          ? 'vegetarian'
        : $self->is_vegetarian_friendly ? 'vegetarian-friendly'
        : 'neither'
    );
}

sub creation_date {
    DateTime::Format::MySQL->parse_datetime( $_[0]->creation_datetime )->ymd;
}

sub first_image {
    my $self = shift;

    return ( $self->images() )[0];
}

sub images {
    my $self = shift;

    return @{ $self->{images} }
        if $self->{images};

    $self->{images} = [
        sort { $a->display_order() <=> $b->display_order() }
            map { VegGuide::VendorImage->new( vendor_image_id => $_ ) }
            $self->image_ids()
    ];

    return @{ $self->{images} };
}

sub image_count {
    my $self = shift;

    return scalar $self->images();
}

sub image_ids {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    $self->{image_ids} ||= [
        $self->_id_list(
            $schema->VendorImage_t(),
            $schema->VendorImage_t()->vendor_image_id_c(),
        )
    ];

    return @{ $self->{image_ids} };
}

my $OrganizationCategoryID
    = VegGuide::Category->Organization
    ? VegGuide::Category->Organization->category_id
    : 0;

sub is_organization {
    my $self = shift;

    my @cat = $self->categories;

    return (
        @cat == 1 && $cat[0]->category_id == $OrganizationCategoryID
        ? 1
        : 0
    );
}

my $RestaurantCategoryID
    = VegGuide::Category->Restaurant
    ? VegGuide::Category->Restaurant->category_id
    : 0;

sub is_restaurant {
    my $self = shift;

    return
        grep { $_->category_id == $RestaurantCategoryID } $self->categories;
}

my $BarCategoryID
    = VegGuide::Category->Bar ? VegGuide::Category->Bar->category_id : 0;
my $CoffeeTeaJuiceCategoryID
    = VegGuide::Category->CoffeeTeaJuice
    ? VegGuide::Category->CoffeeTeaJuice->category_id
    : 0;

sub smoking_is_relevant {
    my $self = shift;

    foreach my $c_id ( map { $_->category_id } $self->categories ) {
        return 1
            if ( $c_id == $BarCategoryID
            || $c_id == $RestaurantCategoryID
            || $c_id == $CoffeeTeaJuiceCategoryID );
    }

    return 0;
}

sub is_smoke_free_description {
    my $self = shift;

    my $val = $self->allows_smoking();
    $val = !$val if defined $val;

    return troolean($val);
}

sub is_wheelchair_accessible_description {
    my $self = shift;

    return troolean( $self->is_wheelchair_accessible() );
}

sub accepts_reservations_description {
    my $self = shift;

    return troolean( $self->accepts_reservations() );
}

sub is_open {
    my $self = shift;
    my %p    = validate(
        @_,
        { minute_margin => { type => SCALAR, default => 0 } },
    );

    return unless $self->location->time_zone;

    my $dt = DateTime->now;
    $dt->set_time_zone( $self->location->time_zone );

    $dt->add( minutes => $p{minute_margin} ) if $p{minute_margin};

    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorHours_t->function(
        select => 1,

        where => [
            [ $schema->VendorHours_t->vendor_id_c, '=', $self->vendor_id ],
            $self->is_open_where_clause($dt),
        ],
    );
}

sub is_open_where_clause {
    my $self = shift;
    my $dt   = shift;
    my $VH   = shift;

    my $day    = $dt->day_of_week - 1;
    my $minute = ( $dt->hour * 60 ) + $dt->minute;

    my $schema = VegGuide::Schema->Connect();

    $VH ||= $schema->VendorHours_t;

    return (
        '(',

        # opened previous day, crosses midnight, and is still open
        (
            '(',
            [ $VH->day_c, '=', $day == 0 ? 7 : $day - 1 ],
            [ $VH->open_minute_c,  '>', $VH->close_minute_c ],
            [ $VH->close_minute_c, '>', $minute ],
            ')',
        ),

        'or',

        # open 24 hours today
        (
            '(',
            [ $VH->day_c,         '=', $day ],
            [ $VH->open_minute_c, '=', $VH->close_minute_c ],
            ')',
        ),

        'or',

        # hours today don't span midnight but include
        # $minute
        (
            '(',
            [ $VH->day_c,          '=',  $day ],
            [ $VH->open_minute_c,  '<',  $VH->close_minute_c ],
            [ $VH->open_minute_c,  '<=', $minute ],
            [ $VH->close_minute_c, '>',  $minute ],
            ')',
        ),

        'or',

        # hours today span midnight and $current_minute is
        # after opening
        (
            '(',
            [ $VH->day_c,         '=',  $day ],
            [ $VH->open_minute_c, '>',  $VH->close_minute_c ],
            [ $VH->open_minute_c, '<=', $minute ],
            ')',
        ),

        ')',
    );
}

sub location {
    my $self = shift;

    return $self->{location}
        if $self->{location}
            && $self->location_id == $self->{location}->location_id;

    return $self->{location}
        = VegGuide::Location->new( location_id => $self->location_id );
}

sub user {
    my $self = shift;

    $self->{user} ||= VegGuide::User->new( user_id => $self->user_id );

    return $self->{user};
}

sub vendor_source {
    my $self = shift;

    my $id = $self->vendor_source_id();
    return unless $id;

    return $self->{vendor_source}
        ||= VegGuide::VendorSource->new( vendor_source_id => $id );
}

{
    my @Cloneable = qw( name localized_name
        short_description localized_short_description
        long_description localized_long_description
        veg_level
        home_page
        price_range_id
        is_cash_only
        accepts_reservations
    );

    sub cloneable_data {
        my $self = shift;

        my %data;
        for my $k (@Cloneable) {
            $data{$k} = $self->$k();
        }

        $data{cuisine_id}        = [ $self->cuisine_ids() ];
        $data{category_id}       = [ $self->category_ids() ];
        $data{payment_option_id} = [ $self->payment_option_id() ];

        return %data;
    }
}

sub microdata_schema {
    my $self = shift;

    $self->{microdata_schema} = $self->_build_microdata_schema()
        unless exists $self->{microdata_schema};

    return $self->{microdata_schema};
}

{
    my $Restaurant = 'http://schema.org/Restaurant';
    my $Coffee     = 'http://schema.org/CafeOrCoffeeShop';
    my $Bar        = 'http://schema.org/BarOrPub';
    my $Lodging    = 'http://schema.org/LodgingBusiness';
    my $NGO        = 'http://schema.org/NGO';
    my $GenericOrg = 'http://schema.org/Organization';

    sub _build_microdata_schema {
        my $self = shift;

        my %cat = map { $_->name() => 1 } $self->categories();

        return $Restaurant
            if $cat{Restaurant}
                || $cat{'Food Court or Street Vendor'};

        return $Coffee  if $cat{'Coffee/Tea/Juice'};
        return $Bar     if $cat{Bar};
        return $Lodging if $cat{'Hotel/B&B'};
        return $NGO     if $cat{Organization};

        return $GenericOrg;
    }
}

sub is_smoke_free {
    my $self = shift;

    my $smoking = $self->allows_smoking();

    return 1 if defined $smoking && !$smoking;
}

sub rest_data {
    my $self = shift;
    my %p    = validate(
        @_,
        { include_related => { type => BOOLEAN, default => 1 } }
    );

    my %rest = map { $_ => $self->$_() }
        grep { !/_id$/ }
        map  { $_->name() } $self->table()->columns();

    delete $rest{$_}
        for qw( canonical_address last_featured_date latitude longitude );

    if ( $self->price_range_id() ) {
        $rest{price_range} = $self->price_range()->description();
    }

    if ( $self->has_hours_info() ) {
        $rest{hours} = [ $self->hours_as_descriptions() ];
    }

    $rest{website} = delete $rest{home_page};

    $rest{veg_level_description} = $self->veg_description();

    for my $dt (qw( creation_datetime last_modified_datetime )) {
        my $meth = $dt . '_object';
        $rest{$dt}
            = DateTime::Format::RFC3339->format_datetime(
            $self->$meth()->clone()->set_time_zone('America/Denver')
                ->set_time_zone('UTC') );
    }

    if ( $self->close_date() ) {
        $rest{close_date} = DateTime::Format::RFC3339->format_datetime(
            $self->close_date_object()->clone()->set_time_zone('UTC') );
    }

    $rest{uri} = entry_uri( vendor => $self, with_host => 1 );
    $rest{reviews_uri}
        = entry_uri( vendor => $self, path => 'reviews', with_host => 1 );

    $rest{categories} = [ map { $_->name() } $self->categories() ];
    $rest{cuisines}   = [ map { $_->name() } $self->cuisines() ];

    $rest{user} = $self->user()->rest_data( include_related => 0 );

    if ( $p{include_related} ) {
        $rest{region} = $self->location()->rest_data( include_related => 0 );
    }

    return \%rest;
}

sub feed_title {
    my $self = shift;

    my $title = $self->name();
    $title .= ' in ' . $self->location->name_with_parent;

    return $title;
}

sub feed_uri {
    my $self = shift;

    return entry_uri( vendor => $self, with_host => 1 );
}

sub feed_template_params {
    my $self = shift;

    return ( '/vendor-entry-content.mas', vendor => $self );
}

sub All {
    my $class = shift;

    return $class->cursor( $class->table->all_rows );
}

sub AllOpen {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    return $class->cursor(
        $class->table->rows_where(
            where => [ $schema->Vendor_t->close_date_c, '=', undef ],
        )
    );
}

sub NewVendorCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            days => { type => SCALAR },
        },
    );

    my $week_ago = DateTime->today()->subtract( days => 7 );

    my $schema = VegGuide::Schema->Connect();

    my @where = (
        $schema->Vendor_t()->creation_datetime_c(),
        '>=',
        DateTime::Format::MySQL->format_datetime($week_ago)
    );

    return $class->VendorCount( where => \@where );
}

sub VendorCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            where => { optional => 1 },
            join  => { optional => 1 },
        },
    );

    my %where;
    %where = ( where => $p{where} )
        if $p{where};

    my $schema = VegGuide::Schema->Connect();

    unless ( $p{join}
        && UNIVERSAL::isa( $p{join}, 'ARRAY' )
        && @{ $p{join} } ) {
        $p{join} = $schema->Vendor_t;
    }

    return $schema->function(
        select => $schema->sqlmaker->COUNT(
            $schema->sqlmaker->DISTINCT( $schema->Vendor_t->vendor_id_c )
        ),
        join => $p{join},
        %where,
    );
}

=pod

Taken from http://jcole.us/blog/archives/2006/05/01/computing-distance-in-miles/

DROP FUNCTION IF EXISTS GREAT_CIRCLE_DISTANCE;

delimiter //

CREATE FUNCTION
  GREAT_CIRCLE_DISTANCE ( radius DOUBLE,
                          v_lat DOUBLE, v_long DOUBLE,
                          p_lat DOUBLE, p_long DOUBLE )
                        RETURNS DOUBLE
  DETERMINISTIC
BEGIN

  RETURN (2
          * radius
          * ATAN2( SQRT( @x := ( POW( SIN( ( RADIANS(v_lat) - RADIANS(p_lat) ) / 2 ), 2 )
                                 + COS( RADIANS( p_lat ) ) * COS( RADIANS(v_lat) )
                                 * POW( SIN( ( RADIANS(v_long) - RADIANS(p_long) ) / 2 ), 2 )
                               )
                       ),
                   SQRT( 1 - @x ) )
         );


END;
//

delimiter ;

=cut

BEGIN {
    Alzabo::SQLMaker::make_function(
        function => 'GREAT_CIRCLE_DISTANCE',
        min      => 5,
        max      => 5,
        groups   => ['udf'],
    );
}

sub VendorsWhere {
    my $class = shift;
    my %p     = validate(
        @_, {
            order_by   => { default  => 'name' },
            sort_order => { default  => 'ASC' },
            limit      => { optional => 1 },
            start      => { default  => 0 },
            where      => { optional => 1 },
            join       => { optional => 1 },
            lat_long   => { optional => 1 },
            unit =>
                { type => SCALAR, regex => qr/^(?:mile|km)$/, optional => 1 },
        },
    );

    my %limit;
    %limit = ( limit => [ $p{limit}, $p{start} ] )
        if $p{limit};

    my %where;
    %where = ( where => $p{where} )
        if $p{where};

    my $schema = VegGuide::Schema->Connect();

    my @join = $p{join} ? @{ $p{join} } : ();
    my @order_by;
    if ( lc $p{order_by} eq 'updated' ) {
        @order_by = (
            $schema->Vendor_t->last_modified_datetime_c,
            $p{sort_order},
            $schema->Vendor_t->sortable_name_c,
            'ASC',
        );
    }
    elsif ( lc $p{order_by} eq 'created' ) {
        @order_by = (
            $schema->Vendor_t->creation_datetime_c,
            $p{sort_order},
            $schema->Vendor_t->sortable_name_c,
            'ASC',
        );
    }
    elsif ( lc $p{order_by} eq 'city' ) {
        @order_by = (
            $schema->Vendor_t->city_c,
            $p{sort_order},
            $schema->Vendor_t->sortable_name_c,
            'ASC',
        );
    }
    elsif ( lc $p{order_by} eq 'price' ) {
        unless (
            grep { $_ eq 'PriceRange' }
            map { $_->[-2], $_->[-1] } @join
            ) {
            push @join, [ $schema->tables( 'Vendor', 'PriceRange' ) ];
        }

        @order_by = (
            $schema->PriceRange_t->display_order_c,
            $p{sort_order},
            $schema->Vendor_t->sortable_name_c,
            'ASC',
        );
    }
    elsif ( lc $p{order_by} eq 'rating' ) {
        my $wr = WEIGHTED_RATING(
            $schema->Vendor_t()->vendor_id_c(),
            $WeightedRatingMinCount,
            $class->AverageRating(),
        );

        my $count
            = $schema->sqlmaker->COUNT( $schema->VendorRating_t->rating_c );

        unless (
            grep { $_ eq 'VendorRating' }
            map { $_->[-2], $_->[-1] } @join
            ) {
            push @join,
                [
                left_outer_join => $schema->tables( 'Vendor', 'VendorRating' )
                ];
        }

        return VegGuide::Cursor::VendorByAggregate->new(
            cursor => $schema->select(
                select => [ $schema->Vendor_t->vendor_id_c, $wr, $count ],
                join   => \@join,
                %where,
                group_by => [ $schema->Vendor_t->vendor_id_c, ],
                order_by => [
                    $wr,
                    $p{sort_order},
                    $count,
                    'DESC',
                    $schema->Vendor_t->sortable_name_c,
                    'ASC',
                ],
                %limit,
            )
        );
    }
    elsif ( lc $p{order_by} eq 'how_veg' ) {
        @order_by = (
            $schema->Vendor_t->veg_level_c,
            $p{sort_order},
            $schema->Vendor_t->sortable_name_c,
            'ASC',
        );
    }
    elsif ( lc $p{order_by} eq 'distance' ) {
        my $radius = earth_radius( $p{unit} );

        my $distance = $schema->sqlmaker()->ROUND(
            GREAT_CIRCLE_DISTANCE(
                $radius,
                $schema->Vendor_t()->latitude_c(),
                $schema->Vendor_t()->longitude_c(),
                @{ $p{lat_long} },
            ),
            1
        );

        @join = $schema->Vendor_t
            unless @join;

        return VegGuide::Cursor::VendorByAggregate->new(
            cursor => $schema->select(
                select => [ $schema->sqlmaker->DISTINCT( $schema->Vendor_t()->vendor_id_c() ), $distance ],
                join   => \@join,
                %where,
                order_by => [
                    $distance,
                    $p{sort_order},
                    $schema->Vendor_t()->sortable_name_c(),
                    'ASC',
                ],
                %limit,
            )
        );

    }

    # XXX - special case for front page
    elsif ( lc $p{order_by} eq 'rand' ) {
        @order_by = $schema->sqlmaker()->RAND();
    }
    else    # name
    {
        @order_by = (
            $schema->Vendor_t->sortable_name_c,
            $p{sort_order},
            $schema->Vendor_t->city_c,
            'ASC',
        );
    }

    @join = $schema->Vendor_t
        unless @join;

    my %order_by;
    $order_by{order_by} = \@order_by
        if @order_by;

    return $class->cursor(
        $schema->join(
            distinct => $schema->Vendor_t,
            join     => \@join,
            %where,
            %order_by,
            %limit,
        )
    );
}

sub CloseCutoffWhereClause {
    my $class = shift;

    my $close_cutoff = DateTime->today()->subtract( months => 6 );

    my $vendor_t = $class->table();

    return (
        '(',
        [ $vendor_t->close_date_c, '=', undef ],
        'or',
        [
            $vendor_t->close_date_c, '>=',
            DateTime::Format::MySQL->format_datetime($close_cutoff)
        ],
        ')',
    );
}

sub IsMappableWhereClause {
    my $class = shift;

    my $vendor_t = $class->table();

    return (
        [ $vendor_t->latitude_c,  '!=', undef ],
        [ $vendor_t->longitude_c, '!=', undef ],
    );
}

sub VendorIdsWithMinimumRating {
    my $class = shift;
    my %p     = validate(
        @_, {
            rating                     => { type => SCALAR },
            location_id                => { type => SCALAR, optional => 1 },
            latitude_longitude_min_max => { type => ARRAYREF, optional => 1 },
            name                       => { type => SCALAR, optional => 1 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my @where;
    if ( $p{location_id} ) {
        @where = ( $schema->Vendor_t->location_id_c, '=', $p{location_id} );
    }
    elsif ( $p{latitude_longitude_min_max} ) {
        @where = $class->LatitudeLongitudeMinMaxWhere(
            $p{latitude_longitude_min_max} );
    }
    elsif ( $p{name} ) {
        @where = $class->NameWhere( $p{name} );
    }
    else {
        die 'No filter for VendorIdsWithMinimumRating';
    }

    my $wr = WEIGHTED_RATING(
        $schema->VendorRating_t()->vendor_id_c(),
        $WeightedRatingMinCount,
        $class->AverageRating(),
    );

    return map { $_->[0] } $schema->function(
        select => [
            $schema->VendorRating_t->vendor_id_c,
            $wr,
        ],
        join     => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
        where    => \@where,
        group_by => $schema->VendorRating_t->vendor_id_c,
        having   => [
            $wr,
            '>=', $p{rating}
        ],
    );
}

sub LatitudeLongitudeMinMaxWhere {
    my $class = shift;
    my ($lat_long) = validate_pos(
        @_, {
            type      => ARRAYREF,
            callbacks => {
                'length is 4' => sub { @{ $_[0] } == 4 ? 1 : 0 },
            },
        }
    );

    return (
        [
            $class->table->latitude_c, 'BETWEEN', $lat_long->[0],
            $lat_long->[1]
        ],
        [
            $class->table->longitude_c, 'BETWEEN', $lat_long->[2],
            $lat_long->[3]
        ],
    );

}

sub NameWhere {
    my $class = shift;
    my $name  = shift;

    my $table = $class->table();

    return (
        '(',
        [ $table->name_c(), 'LIKE', "%$name%" ],
        'or',
        [ $table->localized_name_c(), 'LIKE', "%$name%" ],
        ')',
    );
}

sub ReviewCount {
    return VegGuide::Schema->Connect->VendorComment_t->row_count;
}

sub VendorRatingCount {
    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorRating_t->function(
        select => $schema->sqlmaker->COUNT(
            $schema->sqlmaker->DISTINCT(
                $schema->VendorRating_t->vendor_id_c
            )
        ),
    );
}

sub UserRatingCount {
    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorRating_t->function(
        select => $schema->sqlmaker->COUNT(
            $schema->sqlmaker->DISTINCT( $schema->VendorRating_t->user_id_c )
        ),
    );
}

sub RatingCount {
    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorRating_t->function(
        select =>
            $schema->sqlmaker->COUNT( $schema->VendorRating_t->vendor_id_c ),
    );
}

sub RecentlyChanged {
    my $class = shift;
    my %p     = validate(
        @_, {
            days  => { type => SCALAR, default  => 7 },
            limit => { type => SCALAR, optional => 1 },
        },
    );

    my $since = DateTime->today->subtract( days => $p{days} );

    my %limit;
    $limit{limit} = $p{limit} if $p{limit};

    my $schema = VegGuide::Schema->Connect();

    return $class->cursor(
        $schema->Vendor_t->rows_where(
            where => [
                $schema->Vendor_t->last_modified_datetime_c,
                '>=', DateTime::Format::MySQL->format_datetime($since)
            ],
            order_by =>
                [ $schema->Vendor_t->last_modified_datetime_c, 'DESC' ],
            %limit
        ),
    );
}

sub RecentlyChangedCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            days => { type => SCALAR, default => 7 },
        },
    );

    my $since = DateTime->today->subtract( days => $p{days} );

    my $schema = VegGuide::Schema->Connect();

    return $schema->Vendor_t->row_count(
        where => [
            [
                $schema->Vendor_t->last_modified_datetime_c,
                '>=', DateTime::Format::MySQL->format_datetime($since)
            ],
            [
                $schema->Vendor_t->last_modified_datetime_c,
                '!=',
                $schema->Vendor_t->creation_datetime_c
            ],
        ],
    );
}

sub RecentlyAdded {
    my $class = shift;
    my %p     = validate(
        @_, {
            days  => { type => SCALAR, optional => 1 },
            limit => { type => SCALAR, optional => 1 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my @where = [ $schema->Vendor_t->close_date_c, '=', undef ];

    if ( $p{days} ) {
        my $since = DateTime->today->subtract( days => $p{days} );

        push @where,
            [
            $schema->Vendor_t->creation_datetime_c,
            '>=', DateTime::Format::MySQL->format_datetime($since)
            ];
    }

    my %limit;
    $limit{limit} = $p{limit} if $p{limit};

    return $class->cursor(
        $schema->Vendor_t->rows_where(
            where => \@where,
            order_by =>
                [ $schema->Vendor_t->creation_datetime_c, 'DESC' ],
            %limit
        ),
    );
}

sub RecentlyAddedCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            days => { type => SCALAR, default => 7 },
        },
    );

    my $since = DateTime->today->subtract( days => $p{days} );

    my $schema = VegGuide::Schema->Connect();

    return $schema->Vendor_t->row_count(
        where => [
            [
                $schema->Vendor_t->creation_datetime_c,
                '>=', DateTime::Format::MySQL->format_datetime($since)
            ],
            [ $schema->Vendor_t->close_date_c, '=', undef ],
        ],
    );
}

sub TopRated {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit    => { type => SCALAR,               default  => 5 },
            location => { isa  => 'VegGuide::Location', default  => undef },
            where    => { type => ARRAYREF,             optional => 1 },
            tables   => { type => ARRAYREF,             optional => 1 },
            rating_count => { type => SCALAR, default => 6 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my @tables = $p{tables} ? @{ $p{tables} } : ();
    push @tables, $schema->Vendor_t;

    my @where = $p{where} ? @{ $p{where} } : ();
    push @where, [ $schema->Vendor_t->close_date_c, '=', undef ];

    if ( $p{location} ) {
        push @where,
            [ $schema->Vendor_t->location_id_c, '=',
            $p{location}->location_id ];
    }

    push @tables, $schema->VendorRating_t;

    my $wr = WEIGHTED_RATING(
        $schema->VendorRating_t()->vendor_id_c(),
        $WeightedRatingMinCount,
        $class->AverageRating(),
    );

    # Sorting by avg & then count seems like a good idea, but the
    # averages are returned with 3 digits of precision, whereas we
    # display just 1.  This means even though it looks like a number
    # of vendors have the same rating, they don't when sorting.
    return VegGuide::Cursor::VendorByAggregate->new(
        cursor => $schema->select(
            select => [
                $schema->VendorRating_t->vendor_id_c,
                $wr,
                $schema->sqlmaker->COUNT
                    ( $schema->VendorRating_t->rating_c ),
            ],
            join     => \@tables,
            where    => \@where,
            group_by => $schema->VendorRating_t->vendor_id_c,
            having   => [
                $schema->sqlmaker->COUNT( $schema->VendorRating_t->rating_c ),
                '>=', $p{rating_count}
            ],
            order_by => [
                $wr,
                'DESC',
                $schema->sqlmaker->COUNT
                    ( $schema->VendorRating_t->rating_c ),
                'DESC',
            ],
            limit => $p{limit},
        )
    );
}

sub ByRatingCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit => { type => SCALAR, default => 5 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    return VegGuide::Cursor::VendorByAggregate->new(
        cursor => $schema->select(
            select => [
                $schema->VendorRating_t->vendor_id_c,
                $schema->sqlmaker->COUNT
                    ( $schema->VendorRating_t->rating_c ),
            ],
            join  => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
            where => [
                $schema->Vendor_t->close_date_c,
                '=', undef
            ],
            group_by => $schema->VendorRating_t->vendor_id_c,
            order_by => [
                $schema->sqlmaker->COUNT( $schema->VendorRating_t->rating_c ),
                'DESC',
            ],
            limit => $p{limit},
        )
    );
}

sub ByRating {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit        => { type => SCALAR, default => 5 },
            rating_count => { type => SCALAR, default => 10 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my $wr = WEIGHTED_RATING(
        $schema->Vendor_t()->vendor_id_c(),
        $WeightedRatingMinCount,
        $class->AverageRating(),
    );

    my $count = $schema->sqlmaker->COUNT( $schema->VendorRating_t->rating_c );

    return VegGuide::Cursor::VendorByAggregate->new(
        cursor => $schema->select(
            select => [ $schema->Vendor_t->vendor_id_c, $wr, $count ],
            join  => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
            where => [
                $schema->Vendor_t->close_date_c,
                '=', undef
            ],
            group_by => [ $schema->Vendor_t->vendor_id_c, ],
            having   => [
                $schema->sqlmaker->COUNT( $schema->VendorRating_t->rating_c ),
                '>=', $p{rating_count},
            ],
            order_by => [
                $wr,
                'DESC',
                $count,
                'DESC',
                $schema->Vendor_t->sortable_name_c,
                'ASC',
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

    return VegGuide::Cursor::VendorWithAggregate->new(
        cursor => $schema->select(
            select => [
                $schema->sqlmaker->COUNT(
                    $schema->VendorComment_t->vendor_id_c
                ),
                $schema->VendorComment_t->vendor_id_c
            ],
            join  => [ $schema->tables( 'Vendor', 'VendorComment' ) ],
            where => [
                $schema->Vendor_t->close_date_c,
                '=', undef
            ],
            group_by => $schema->VendorComment_t->vendor_id_c,
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

sub RecentlyReviewedCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            days => { type => SCALAR, default => 7 },
        },
    );

    my $since = DateTime->today->subtract( days => $p{days} );

    my $schema = VegGuide::Schema->Connect();

    return $schema->row_count(
        join  => [ $schema->tables( 'Vendor', 'VendorComment', 'User' ) ],
        where => [
            $schema->VendorComment_t->last_modified_datetime_c,
            '>=', DateTime::Format::MySQL->format_datetime($since)
        ],
    );
}

sub RecentlyReviewed {
    my $class = shift;
    my %p     = validate(
        @_, {
            days         => { type => SCALAR | UNDEF,    default => 7 },
            location_ids => { type => SCALAR | ARRAYREF, default => undef },
            limit        => { type => SCALAR,            default => 10 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my @where;

    if ( $p{days} ) {
        my $since = DateTime->today->subtract( days => $p{days} );

        push @where,
            [
            $schema->VendorComment_t->last_modified_datetime_c,
            '>=', DateTime::Format::MySQL->format_datetime($since)
            ],
            ;
    }

    if ( $p{location_ids} ) {
        my @ids
            = ref $p{location_ids} ? @{ $p{location_ids} } : $p{location_ids};

        push @where, [ $class->table->location_id_c, 'IN', @ids ];
    }

    my %limit;
    $limit{limit} = $p{limit} if $p{limit};

    my %where;
    $where{where} = \@where if @where;

    return $class->cursor(
        $schema->join(
            join => [ $schema->tables( 'Vendor', 'VendorComment', 'User' ) ],
            %where,
            order_by => [
                $schema->VendorComment_t->last_modified_datetime_c, 'DESC'
            ],
            %limit
        ),
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

sub ClosedCount {
    my $class = shift;

    return $class->table()
        ->row_count(
        where => [ $class->table()->close_date_c(), '!=', undef ] );
}

sub CountForDateSpan {
    my $class = shift;
    my %p     = validate(
        @_, {
            start_date => { isa => 'DateTime' },
            end_date   => { isa => 'DateTime' },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    return $class->table->function(
        select => $schema->sqlmaker->COUNT( $class->table->vendor_id_c ),
        where  => [
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

sub RandomCompleteVendor {
    my $class = shift;

    my @vendor_ids_with_images = VegGuide::VendorImage->AllVendorIds;
    return unless @vendor_ids_with_images;

    my $schema = VegGuide::Schema->Connect();

    my @where = (
        [ $schema->Vendor_t->long_description_c, '!=', undef ],
        [ $schema->Vendor_t->vendor_id_c,  'IN', @vendor_ids_with_images ],
        [ $schema->Vendor_t->close_date_c, '=',  undef ],
    );

    my $row = $schema->Vendor_t->one_row(
        where => [
            @where,
            [ $schema->Vendor_t->last_featured_date_c, '=', undef ],
        ],
        order_by => $schema->sqlmaker->RAND,
    );

    return $class->new( object => $row ) if $row;

    my $min_date = $schema->Vendor_t->function(
        select =>
            $schema->sqlmaker->MIN( $schema->Vendor_t->last_featured_date_c ),
        where => \@where,
    );

    $row = $schema->Vendor_t->one_row(
        where => [
            @where,
            [ $schema->Vendor_t->last_featured_date_c, '=', $min_date ],
        ],
        order_by => $schema->sqlmaker->RAND,
    );

    return $class->new( object => $row ) if $row;
}

sub ActiveVendorCount {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my @where = VegGuide::Vendor->CloseCutoffWhereClause();

    return VegGuide::Vendor->VendorCount( where => \@where );
}

sub ActiveVendors {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my @where = VegGuide::Vendor->CloseCutoffWhereClause();

    return VegGuide::Vendor->VendorsWhere(
        @_,
        where => \@where,
    );
}

sub UnGeocoded {
    my $class = shift;

    my @location_ids
        = map { ( $_->descendant_ids(), $_->location_id() ) }
        map { VegGuide::Location->new( name => $_ ) }
        VegGuide::Geocoder->Countries();

    my $table = $class->table();

    return $class->VendorsWhere(
        where => [
            [
                $table->location_id_c(),
                'IN', @location_ids
            ],
            [ $table->latitude_c(), '=',        undef ],
            [ $table->address1_c(), '!=',       undef ],
            [ $table->address1_c(), 'NOT LIKE', 'po%' ],
            [ $table->address1_c(), 'NOT LIKE', 'p.o.%' ],
        ],
        order_by   => 'created',
        sort_order => 'desc',
    );
}

{
    my $sql = <<'EOF';
SELECT V1.vendor_id, V2.vendor_id
  FROM Vendor AS V1, Vendor AS V2
 WHERE V1.canonical_address IS NOT NULL
   AND V2.canonical_address IS NOT NULL
   AND V1.address1 IS NOT NULL
   AND V2.address1 IS NOT NULL
   AND V1.close_date IS NULL
   AND V2.close_date IS NULL
   AND V1.canonical_address = V2.canonical_address
   AND V1.vendor_id != V2.vendor_id
ORDER BY V1.last_modified_datetime DESC,
         V1.name ASC
EOF

    sub PossibleDuplicates {
        my $class = shift;

        my $schema = VegGuide::Schema->Connect();

        my $sth_handle = $schema->driver()->statement( sql => $sql );

        return VegGuide::Cursor::DuplicateVendors->new(
            cursor => $sth_handle );
    }
}

1;
