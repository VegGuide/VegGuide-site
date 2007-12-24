package VegGuide::Location;

use strict;
use warnings;

use base 'VegGuide::CachedHierarchy';

use VegGuide::Schema;
use VegGuide::AlzaboWrapper
    ( table => VegGuide::Schema->Schema->Location_t,
      skip  => [ 'can_have_vendors' ]
    );

use DateTime;
use DateTime::Format::MySQL;
use DateTime::Format::W3CDTF;
use DateTime::TimeZone;
use File::Basename qw( dirname );
use File::Copy qw( move );
use File::Path qw( mkpath );
use File::Spec;
use File::Temp ();
use Geography::States;
use List::MoreUtils qw( uniq );
use List::Util qw( first sum );
use LockFile::Simple;
use URI::FromHash qw( uri );
use VegGuide::Config;
use VegGuide::Exceptions qw( auth_error data_validation_error );
use VegGuide::Locale;
use VegGuide::RSSWriter;
use VegGuide::SiteURI qw( entry_uri region_uri );
use VegGuide::Util qw( string_is_empty );
use VegGuide::Vendor;
use XML::Feed;

use VegGuide::Validate qw( validate validate_with UNDEF SCALAR ARRAYREF BOOLEAN SCALAR_TYPE );


# Needs to be defined before we build the cache
my %NoAddresses = map { $_ => 1 } qw( Internet );
my %NoHours     = map { $_ => 1 } qw( Internet );

my %CacheParams = ( parent => 'parent_location_id',
                    roots  => '_RealRootLocations',
                    id     => 'location_id',
                    order_by => VegGuide::Schema->Schema->Location_t->name_c,
                  );

__PACKAGE__->_build_cache( %CacheParams, first => 1 );
__PACKAGE__->_PreloadTimeZones;

# The time zone objects use up a lot of memory, but are unlikely to
# change once first loaded.  These objects are singletons, so loading
# them in the parent process can be a big win by keeping them all in
# shared memory.
sub _PreloadTimeZones
{
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my $zones =
        $schema->Location_t->select
            ( select =>
              $schema->sqlmaker->DISTINCT
                  ( $schema->Location_t->time_zone_name_c ),
              where =>
              [ $schema->Location_t->time_zone_name_c, '!=', '' ],
            );

    while ( my $name = $zones->next )
    {
        next unless DateTime::TimeZone->is_valid_name($name);

        DateTime::TimeZone->new( name => $name );
    }
}

sub _RealRootLocations
{
    my $schema = VegGuide::Schema->Connect();

    return
        $_[0]->cursor
            ( $schema->Location_t->rows_where
                  ( where =>
                    [ [ $schema->Location_t->parent_location_id_c, '=', undef ],
                    ],
                    order_by =>
                    [ $schema->Location_t->name_c, 'ASC' ],
                  )
            );
}

sub new
{
    my $class = shift;
    my %p = validate_with( params => \@_,
                           spec =>
                           { location_id => { type => SCALAR, optional => 1 },
                           },
                           allow_extra => 1,
                         );

    if ( $p{location_id} )
    {
        my $location = $class->ByID( $p{location_id} );
        return $location if $location;
    }

    my $self = $class->SUPER::new(@_);

    return unless $self;

    if ( $self->name() )
    {
        $self->{has_addresses} = $NoAddresses{ $self->name } ? 0 : 1;
        $self->{has_hours}     = $NoHours{ $self->name } ? 0 : 1;
    }

    return $self;
}

sub _new_row
{
    my $class = shift;
    my %p = validate_with( params => \@_,
                           spec =>
                           { name => { type => SCALAR, optional => 1 },
                           },
                           allow_extra => 1,
                         );

    my $schema = VegGuide::Schema->Connect();

    if ( $p{name} )
    {
	my @where;
	push @where,
	    [ $schema->sqlmaker->LCASE( $schema->Location_t->name_c ),
              '=', lc $p{name} ];

	return $schema->Location_t->one_row( where => \@where );
    }

    return;
}

sub create
{
    my $class = shift;
    my %p     = @_;

    my $schema = VegGuide::Schema->Connect();

    my $location;

    $schema->begin_work;

    eval
    {
        $location =
            $class->SUPER::create( @_,
                                   creation_datetime => $schema->sqlmaker->NOW(),
                                 );

        my $user = VegGuide::User->new( user_id => $p{user_id} );
        $user->insert_activity_log( type        => 'add region',
                                    location_id => $location->location_id(),
                                  );

        $class->_cached_data_has_changed;

        $schema->commit;
    };

    if ( my $e = $@ )
    {
        eval { $schema->rollback };

        die $e;
    }

    return $location;
}

sub update
{
    my $self = shift;

    $self->SUPER::update(@_);

    $self->_cached_data_has_changed;
}

sub _validate_data
{
    my $self = shift;
    my $data = shift;
    my $is_update = ref $self ? 1 : 0;

    my @errors;

    push @errors, 'Regions must have a name.'
        if string_is_empty( $data->{name} );

    my $parent;
    unless ($is_update)
    {
        $parent = VegGuide::Location->new( location_id => $data->{parent_location_id} );

        push @errors, 'Invalid parent region.'
            if $data->{parent_location_id} && ! $parent;
    }

    push @errors, 'Invalid time zone name'
        if $data->{time_zone_name}
           && ! eval { DateTime::TimeZone->new( name => $data->{time_zone_name} ) };

    push @errors, 'Invalid locale id'
        if $data->{locale_id}
           && ! VegGuide::Locale->new( locale_id => $data->{locale_id} );

    data_validation_error error => "One or more data validation errors", errors => \@errors
        if @errors;

    delete $data->{localized_name}
        if string_is_empty( $data->{localized_name} );

    delete $data->{time_zone_name}
        if $data->{time_zone_name} && $parent
           && $data->{time_zone_name} eq ( $parent->time_zone_name() || '' );

    delete $data->{time_zone_name}
        if string_is_empty( $data->{time_zone_name} );

    delete $data->{locale_id}
        if $data->{locale_id} && $parent
           && $data->{locale_id} == ( $parent->locale_id() || 0 );

    delete $data->{locale_id}
        unless $data->{locale_id};
}

sub delete
{
    my $self = shift;

    $self->SUPER::delete(@_);

    $self->_cached_data_has_changed();
}

sub descendants_vendor_count
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Vendor_t->row_count
            ( where =>
              [ [ $schema->Vendor_t->location_id_c,
                'IN', $self->location_id, $self->descendant_ids ],
                [ $schema->Vendor_t->close_date_c,
                  '=', undef ],
              ],
            );
}

sub comment_count
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->LocationComment_t->row_count
            ( where =>
              [ $schema->LocationComment_t->location_id_c,
                '=', $self->location_id ],
            );
}

sub comments
{
    my $self = shift;
    my %p = validate( @_,
                      { order_by   => { type => SCALAR, default => 'last_modified_datetime' },
                        sort_order => { type => SCALAR, default => 'DESC' },
                      },
                    );

    my $schema = VegGuide::Schema->Connect();

    return
        $self->cursor
            ( $schema->join
                  ( join  => [ $schema->tables( 'LocationComment', 'User' ) ],
                    where =>
                    [ $schema->LocationComment_t->location_id_c,
                      '=', $self->location_id ],
                    order_by =>
                    [ $schema->LocationComment_t->column( $p{order_by} ),
                      $p{sort_order} ],
                  )
            );
}

sub add_or_update_comment
{
    my $self = shift;
    my %p = validate( @_,
                      { user => { isa => 'VegGuide::User' },
                        comment => { type => UNDEF | SCALAR },
                        calling_user => { isa => 'VegGuide::User' },
                      },
                    );

    data_validation_error "Comments must have content."
        unless defined $p{comment} && length $p{comment};

    if ( $p{user}->user_id != $p{calling_user}->user_id )
    {
        auth_error "Cannot edit other user's comments"
            unless $p{calling_user}->is_location_owner($self);
    }

    my $schema = VegGuide::Schema->Connect();

    my $comment;
    if ( $comment = $self->comment_by_user( $p{user} ) )
    {
        $comment->update( comment => $p{comment},
                          last_modified_datetime =>
                          $schema->sqlmaker->NOW(),
                        );
    }
    else
    {
        $comment =
            VegGuide::LocationComment->create
                ( user_id => $p{user}->user_id,
                  location_id => $self->location_id,
                  comment => $p{comment},
                  last_modified_datetime =>
                  $schema->sqlmaker->NOW(),
                );
    }

    return $comment;
}

sub comment_by_user
{
    my $self = shift;
    my $user = shift;

    VegGuide::LocationComment->new( user_id => $user->user_id,
                                    location_id => $self->location_id );
}

sub active_vendor_count
{
    my $self = shift;
    my %p = validate_with( params => \@_,
                           spec =>
                           { where => { type => ARRAYREF, optional => 1 },
                           },
                           allow_extra => 1,
                         );

    my $schema = VegGuide::Schema->Connect();

    my @where;
    if ( $p{where} )
    {
        @where =
            ( @{ $p{where} },
              [ $schema->Vendor_t->location_id_c, '=', $self->location_id ]
            );
    }
    else
    {
        @where =
            [ $schema->Vendor_t->location_id_c, '=', $self->location_id ];
    }

    push @where,
        VegGuide::Vendor->CloseCutoffWhereClause();

    $p{where} = \@where;

    return VegGuide::Vendor->VendorCount(%p);
}

sub open_vendor_count
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        VegGuide::Vendor->VendorCount
            ( where =>
              [ [ $schema->Vendor_t->location_id_c, '=', $self->location_id ],
                [ $schema->Vendor_t->close_date_c, '=', undef ],
              ],
            );
}

sub vendor_count
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        VegGuide::Vendor->VendorCount
            ( where =>
              [ $schema->Vendor_t->location_id_c, '=', $self->location_id ],
            );
}

sub vendors
{
    my $self = shift;
    my %p = validate_with( params => \@_,
                           spec =>
                           { where => { type => ARRAYREF, optional => 1 },
                           },
                           allow_extra => 1,
                         );

    my $schema = VegGuide::Schema->Connect();

    my @where;
    if ( $p{where} )
    {
        @where =
            ( @{ $p{where} },
              [ $schema->Vendor_t->location_id_c, '=', $self->location_id ]
            );
    }
    else
    {
        @where =
            [ $schema->Vendor_t->location_id_c, '=', $self->location_id ];
    }

    $p{where} = \@where;

    return VegGuide::Vendor->VendorsWhere(%p);
}

sub review_count
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->row_count
            ( join =>
              [ $schema->tables( 'Vendor', 'VendorComment' ) ],
              where =>
              [ [ $schema->Vendor_t->location_id_c,
                  '=', $self->location_id ],
                [ $schema->Vendor_t->close_date_c,
                  '=', undef ],
              ],
            );
}

sub vendors_by_review_count
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );

    my $schema = VegGuide::Schema->Connect();

    my $count = $schema->sqlmaker->COUNT( $schema->VendorComment_t->user_id_c );

    return
        VegGuide::Cursor::VendorWithAggregate->new
            ( cursor =>
              $schema->select
                  ( select =>
                    [ $count,
                      $schema->VendorComment_t->vendor_id_c
                    ],
                    join =>
                    [ $schema->tables( 'Vendor', 'VendorComment' ) ],
                    where =>
                    [ [ $schema->Vendor_t->location_id_c,
                        '=', $self->location_id ],
                      [ $schema->Vendor_t->close_date_c,
                        '=', undef ],
                    ],
                    group_by =>
                    $schema->VendorComment_t->vendor_id_c,
                    order_by =>
                    [ $count,
                      'DESC',
                    ],
                    limit => $p{limit},
                  )
            );
}

sub vendors_by_rating_count
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );

    my $schema = VegGuide::Schema->Connect();

    my $count = $schema->sqlmaker->COUNT( $schema->VendorRating_t->user_id_c );

    return
        VegGuide::Cursor::VendorWithAggregate->new
            ( cursor =>
              $schema->select
                  ( select =>
                    [ $count,
                      $schema->VendorRating_t->vendor_id_c
                    ],
                    join =>
                    [ $schema->tables( 'Vendor', 'VendorRating' ) ],
                    where =>
                    [ [ $schema->Vendor_t->location_id_c,
                        '=', $self->location_id, ],
                      [ $schema->Vendor_t->close_date_c,
                        '=', undef ],
                    ],
                    group_by =>
                    $schema->VendorRating_t->vendor_id_c,
                    order_by =>
                    [ $count,
                      'DESC',
                    ],
                    limit => $p{limit},
                  )
            );
}

sub descendant_vendors
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        VegGuide::Vendor->VendorsWhere
            ( where =>
              [ [ $schema->Vendor_t->location_id_c,
                  'IN', $self->location_id, $self->descendant_ids ],
                [ $schema->Vendor_t->close_date_c,
                  '=', undef ],
              ],
            );
}

sub most_recent_vendors
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );


    my $schema = VegGuide::Schema->Connect();

    return
        VegGuide::Vendor->VendorsWhere
            ( where    =>
              [ $schema->Vendor_t->location_id_c,
                '=', $self->location_id ],
              order_by   => 'created',
              sort_order => 'DESC',
              limit      => $p{limit},
            );
}

sub most_recent_reviews
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );

    return
        VegGuide::Vendor->RecentlyReviewed
            ( location_ids => [ $self->location_id ],
              days         => undef, # most recent no matter how old
              limit        => $p{limit},
            );
}

sub top_vendors
{
    my $self = shift;

    return VegGuide::Vendor->TopRated( location => $self, @_ );
}

sub top_restaurants
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        VegGuide::Vendor->TopRated
            ( location => $self,
              where    => [ [ $schema->VendorCategory_t->category_id_c,
                              '=', VegGuide::Category->Restaurant->category_id ] ],
              tables   => [ $schema->VendorCategory_t ],
              @_,
            );
}

sub users_by_entry_count
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );

    my $schema = VegGuide::Schema->Connect();

    my $count = $schema->sqlmaker->COUNT( $schema->Vendor_t->vendor_id_c );

    return
        VegGuide::Cursor::UserWithAggregate->new
            ( cursor =>
              $schema->Vendor_t->select
                  ( select =>
                    [ $count,
                      $schema->Vendor_t->user_id_c
                    ],
                    where =>
                    [ $schema->Vendor_t->location_id_c,
                      '=', $self->location_id ],
                    group_by =>
                    $schema->Vendor_t->user_id_c,
                    order_by =>
                    [ $count,
                      'DESC',
                    ],
                    limit => $p{limit},
                  )
            );
}

sub users_by_review_count
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );

    my $schema = VegGuide::Schema->Connect();

    my $count = $schema->sqlmaker->COUNT( $schema->VendorComment_t->vendor_id_c );

    return
        VegGuide::Cursor::UserWithAggregate->new
            ( cursor =>
              $schema->select
                  ( select =>
                    [ $count,
                      $schema->VendorComment_t->user_id_c
                    ],
                    join =>
                    [ $schema->tables( 'Vendor', 'VendorComment' ) ],
                    where =>
                    [ $schema->Vendor_t->location_id_c,
                      '=', $self->location_id ],
                    group_by =>
                    $schema->VendorComment_t->user_id_c,
                    order_by =>
                    [ $count,
                      'DESC',
                    ],
                    limit => $p{limit},
                  )
            );
}

sub can_have_vendors
{
    my $self = shift;

    return $self->select('can_have_vendors') || ! $self->child_count;
}

sub can_have_child_regions
{
    my $self = shift;

    return 1 if $self->child_count() || ! $self->vendor_count();
    return 0;
}

sub average_rating
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->function
            ( select => AVG( $schema->VendorRating_t()->rating_c() ),
              join   => [ $schema->tables( 'Vendor', 'VendorRating' ) ],
              where  => [ $schema->Vendor_t()->location_id(),
                          '=', $self->location_id() ],
            );
}

sub has_addresses { $_[0]->{has_addresses} }
sub has_hours     { $_[0]->{has_hours} }

sub time_zone
{
    my $self = shift;

    foreach my $l ( $self, $self->ancestors )
    {
        my $tz = $l->time_zone_name;
        return $tz if $tz;
    }
}

sub locale
{
    my $self = shift;

    foreach my $l ( $self, $self->ancestors )
    {
        my $id = $l->locale_id;

        return VegGuide::Locale->new( locale_id => $id )
            if $id;
    }
}

sub address_format { $_[0]->locale ? $_[0]->locale->address_format : 'standard' }

sub country
{
    my $self = shift;

    foreach my $l ( $self, $self->ancestors )
    {
        return $l->name if $l->is_country;
    }
}

sub creator
{
    my $self = shift;

    $self->{creator} ||= VegGuide::User->new( user_id => $self->user_id() );

    return $self->{creator};
}

sub current_cities
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Vendor_t->function
            ( select =>
              $schema->sqlmaker->DISTINCT
                  ( $schema->Vendor_t->city_c ),
              where  =>
              [ [ $schema->Vendor_t->location_id_c,
                  '=', $self->location_id ],
                [ $schema->Vendor_t->city_c, '!=', undef ],
              ],
              order_by => $schema->Vendor_t->city_c,
            );
}

sub current_neighborhoods
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Vendor_t->function
            ( select =>
              $schema->sqlmaker->DISTINCT
                  ( $schema->Vendor_t->neighborhood_c ),
              where  =>
              [ [ $schema->Vendor_t->location_id_c,
                  '=', $self->location_id ],
                [ $schema->Vendor_t->neighborhood_c, '!=', undef ],
              ],
              order_by => $schema->Vendor_t->neighborhood_c,
            );
}

sub current_localized_neighborhoods
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Vendor_t->function
            ( select =>
              $schema->sqlmaker->DISTINCT
                  ( $schema->Vendor_t->localized_neighborhood_c ),
              where  =>
              [ [ $schema->Vendor_t->location_id_c,
                  '=', $self->location_id ],
                [ $schema->Vendor_t->localized_neighborhood_c, '!=', undef ],
              ],
              order_by => $schema->Vendor_t->localized_neighborhood_c,
            );
}

{
    my %StatesForCountry =
        ( USA       => Geography::States->new('USA'),
          Canada    => Geography::States->new('Canada'),
          Australia => Geography::States->new('Australia'),
          Brazil    => Geography::States->new('Brazil'),
          'The Netherlands' => Geography::States->new('The Netherlands'),
        );

    sub normalize_region
    {
        my $self   = shift;
        my $region = shift;

        return $region if defined $region && length $region > 3;

        my $country = $self->country;

        if ( $country && $StatesForCountry{$country} )
        {
            my $long = $StatesForCountry{$country}->state($region);

            $region = $long if defined $long;
        }

        return $region;
    }

    sub region_abbreviation
    {
        my $self = shift;
        my $region = shift;

        return $region if defined $region && length $region <= 3;

        # for handling Quebec
        $region =~ s/\x{E9}/e/
            if defined $region;

        my $country = $self->country;

        if ( $country && $StatesForCountry{$country} )
        {
            my $short = $StatesForCountry{$country}->state($region);

            $region = $short if defined $short;
        }

	# bug in Geography::States
	$region = 'QC' if defined $region && $region eq 'PQ';

        return $region;
    }

    sub GeoStatesObjects
    {
        return @StatesForCountry{ qw( USA Canada Australia Brazil ), 'The Netherlands' };
    }
}

sub owner_count
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->row_count
            ( join   => [ $schema->tables( 'LocationOwner', 'User' ) ],
              where  =>
              [ $schema->LocationOwner_t->location_id_c,
                '=', $self->location_id ],
            )
}

sub owners
{
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return
        $self->cursor
            ( $schema->join
                  ( select => $schema->User_t,
                    join   => [ $schema->tables( 'LocationOwner', 'User' ) ],
                    where  =>
                    [ $schema->LocationOwner_t->location_id_c,
                      '=', $self->location_id ],
                    order_by => [ $schema->User_t->real_name_c, 'ASC' ],
                  )
            );
}

sub add_owner
{
    my $self = shift;
    my $user = shift;

    eval
    {
        VegGuide::Schema->Connect->LocationOwner_t->insert
            ( values =>
              { location_id => $self->location_id,
                user_id     => $user->user_id,
              }
            );
    };

    warn $@ if $@;
}

sub remove_owner
{
    my $self = shift;
    my $user = shift;

    eval
    {
        my $row =
            VegGuide::Schema->Connect->LocationOwner_t->row_by_pk
                ( pk =>
                  { location_id => $self->location_id,
                    user_id     => $user->user_id,
                  }
                );

        $row->delete;
    };

    warn $@ if $@;
}

sub new_vendors_and_reviews_feed
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 10 } }
                    );

    my $schema = VegGuide::Schema->Connect();

    my $feed = $self->_as_xml_feed();

    my $description = "The $p{limit} most recent entries and reviews in " . $self->name;
    $description .= ', ' . $self->parent->name if $self->parent;
    $description .= '.';

    $feed->description($description);

    my $count = 0;
    $count += $self->_add_vendors_to_feed( $feed, $p{limit} );
    $count += $self->_add_reviews_to_feed( $feed, $p{limit} );

    unless ($count)
    {
        my $entry = XML::Feed::Entry->new();
        $entry->title( 'No entries or reviews for this region.' );
        $entry->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
        $entry->summary( 'This region appears to be empty.' );

        $feed->add_entry($entry);
    }

    return $feed;
}

sub new_vendors_feed
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 10 } }
                    );

    my $schema = VegGuide::Schema->Connect();

    my $feed = $self->_as_xml_feed();

    my $description = "The $p{limit} most recent entries in " . $self->name;
    $description .= ', ' . $self->parent->name if $self->parent;
    $description .= '.';

    $feed->description($description);

    my $count = 0;
    $count += $self->_add_vendors_to_feed( $feed, $p{limit} );

    unless ($count)
    {
        my $entry = XML::Feed::Entry->new();
        $entry->title( 'No entries for this region.' );
        $entry->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
        $entry->summary( 'This region has no entries.' );

        $feed->add_entry($entry);
    }

    return $feed;
}

sub new_reviews_feed
{
    my $self = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 10 } }
                    );

    my $feed = $self->_as_xml_feed();

    my $description = "The $p{limit} most recent reviews in " . $self->name;
    $description .= ', ' . $self->parent->name if $self->parent;
    $description .= '.';

    $feed->description($description);

    my $count = 0;
    $count += $self->_add_reviews_to_feed( $feed, $p{limit} );

    unless ($count)
    {
        my $entry = XML::Feed::Entry->new();
        $entry->title( 'No reviews for this region.' );
        $entry->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
        $entry->summary( 'This region has no reviews.' );

        $feed->add_entry($entry);
    }

    return $feed;
}

sub _add_vendors_to_feed
{
    my $self  = shift;
    my $feed  = shift;
    my $limit = shift;

    my $schema = VegGuide::Schema->Connect();

    my $vendors =
        VegGuide::Vendor->VendorsWhere
            ( where    =>
              [ $schema->Vendor_t->location_id_c, 'IN',
                $self->location_id, $self->descendant_ids ],
              order_by   => 'created',
              sort_order => 'DESC',
              limit      => $limit,
            );

    my $count = 0;
    while ( my $vendor = $vendors->next )
    {
        $feed->add_entry( $vendor->as_xml_feed_entry() );
        $count++;
    }

    return $count;
}

sub _add_reviews_to_feed
{
    my $self  = shift;
    my $feed  = shift;
    my $limit = shift;

    my $schema = VegGuide::Schema->Connect();

    my $reviews =
        VegGuide::Vendor->RecentlyReviewed
            ( location_ids => [ $self->location_id, $self->descendant_ids ],
              days         => undef, # most recent no matter how old
              limit        => $limit );

    my $count = 0;
    while ( my ( $vendor, $comment, $user ) = $reviews->next )
    {
        $feed->add_entry( $comment->as_xml_feed_entry() );
        $count++;
    }

    return $count;
}

sub _as_xml_feed
{
    my $self = shift;

    my $feed = XML::Feed->new();

    $feed->title( 'VegGuide.Org: ' . $self->name() );
    $feed->link( region_uri( location => $self, with_host => 1 ) );

    $feed->author( 'Compassionate Action for Animals' );
    $feed->copyright( 'Copyright 2002 - ' . DateTime->now()->year()
                      . q{ } . $feed->author() );

    return $feed;
}

sub data_feed_rss_file
{
    my $self = shift;
    my %p    = validate( @_, { cache_only => { type => BOOLEAN, default => 0 } } );

    my $cache_file =
        File::Spec->catfile
                ( VegGuide::Config->CacheDir(), 'rss',
                  'location-' . $self->location_id() . '.rss',
                );

    $self->_regen_cached_file( $cache_file, sub { $self->_data_feed_handle() } )
        unless $p{cache_only};

    return $cache_file;
}

sub _data_feed_handle
{
    my $self = shift;

    my $w = VegGuide::RSSWriter->new();

    $w->add_location_for_data_feed( location => $self, @_ );

    return $w->fh();
}

{
    my $MaxCacheAge = 5 * 60;
    my $Locker = LockFile::Simple->make( -autoclean => 1, -delay => 1, -max => 15 );

    sub _regen_cached_file
    {
        shift;
        my $cache_file = shift;
        my $data_sub   = shift;

        return $cache_file
            if -f $cache_file && ( stat $cache_file )[9] >= time - $MaxCacheAge;

        return $cache_file unless $Locker->lock($cache_file);

        eval
        {
            my $fh = $data_sub->();
            $fh->close;

            mkpath( dirname( $cache_file ), 0, 0755 );

            my $temp_file = $fh->filename();
            move( $temp_file, $cache_file )
                or die "Cannot move $temp_file to $cache_file: $!";
        };

        $Locker->unlock($cache_file);

        die $@ if $@;

        return $cache_file;
    }
}

sub rest_data
{
    my $self = shift;

    my %rest = ( name        => $self->name(),
                 uri         => region_uri( location => $self ),
                 location_id => $self->location_id(),
               );

    if ( my $parent = $self->parent() )
    {
        $rest{parent} = { name => $parent->name(),
                          uri  => region_uri( location => $parent ),
                        };
    }

    return \%rest;
}

sub NewVendorsAndReviewsFeed
{
    my $class = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 10 } }
                    );

    my $schema = VegGuide::Schema->Connect();

    my $feed = $class->_AsXMLFeed();
    $feed->description( "The $p{limit} most recent entries and reviews on VegGuide.org." );

    my $count = 0;
    $count += $class->_AddVendorsToFeed( $feed, $p{limit} );
    $count += $class->_AddReviewsToFeed( $feed, $p{limit} );

    unless ($count)
    {
        my $entry = XML::Feed::Entry->new();
        $entry->title( 'No entries or reviews in the system.' );
        $entry->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
        $entry->summary( 'The whole database is empty?!' );

        $feed->add_entry($entry);
    }

    return $feed;
}

sub NewVendorsFeed
{
    my $class = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 10 } }
                    );

    my $schema = VegGuide::Schema->Connect();

    my $feed = $class->_AsXMLFeed();
    $feed->description( "The $p{limit} most recent entries on VegGuide.org." );

    my $count = 0;
    $count += $class->_AddVendorsToFeed( $feed, $p{limit} );

    unless ($count)
    {
        my $entry = XML::Feed::Entry->new();
        $entry->title( 'No entries in the system.' );
        $entry->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
        $entry->summary( 'The whole database is empty?!' );

        $feed->add_entry($entry);
    }

    return $feed;
}


sub NewReviewsFeed
{
    my $class = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 10 } }
                    );

    my $schema = VegGuide::Schema->Connect();

    my $feed = $class->_AsXMLFeed();
    $feed->description( "The $p{limit} most recent reviews on VegGuide.org." );

    my $count = 0;
    $count += $class->_AddReviewsToFeed( $feed, $p{limit} );

    unless ($count)
    {
        my $entry = XML::Feed::Entry->new();
        $entry->title( 'No reviews in the system.' );
        $entry->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
        $entry->summary( 'The whole database is empty?!' );

        $feed->add_entry($entry);
    }

    return $feed;
}

sub _AsXMLFeed
{
    my $class = shift;

    my $feed = XML::Feed->new();

    $feed->title( q{VegGuide.Org: What's New} );
    $feed->link( uri( scheme => 'http', host => VegGuide::Config->CanonicalWebHostname() ) );
    $feed->author( 'Compassionate Action for Animals' );
    $feed->copyright( 'Copyright 2002 - ' . DateTime->now()->year()
                      . q{ } . $feed->author() );

    return $feed;
}

sub _AddVendorsToFeed
{
    my $class = shift;
    my $feed  = shift;
    my $limit = shift;

    my $count = 0;

    my $vendors = VegGuide::Vendor->RecentlyAdded( limit => $limit );
    while ( my $vendor = $vendors->next )
    {
        $feed->add_entry( $vendor->as_xml_feed_entry() );
        $count++;
    }

    return $count;
}

sub _AddReviewsToFeed
{
    my $class = shift;
    my $feed  = shift;
    my $limit = shift;

    my $count = 0;

    my $reviews =
        VegGuide::Vendor->RecentlyReviewed
            ( days  => undef, # most recent no matter how old
              limit => $limit,
            );
    while ( my ( $vendor, $comment, $user ) = $reviews->next )
    {
        $feed->add_entry( $comment->as_xml_feed_entry() );
        $count++;
    }

    return $count;
}

sub DataFeedRSSFile
{
    my $class = shift;

    my $cache_file =
        File::Spec->catfile
                ( VegGuide::Config->CacheDir(), 'rss',
                  'site.rss',
                );

    $class->_regen_cached_file( $cache_file, sub { return $class->_DataFeedHandle() } );

    return $cache_file;
}

sub _DataFeedHandle
{
    my $w = VegGuide::RSSWriter->new();

    my $vendors = VegGuide::Vendor->All();

    while ( my $v = $vendors->next() )
    {
        $w->add_vendor_for_data_feed( vendor => $v );
    }

    $w->site_channel( 'VegGuide.Org Data Feed',
                      'Data feed of all entries in the VegGuide.Org system.',
                    );

    return $w->fh();
}

sub DataFeedDynamicLimit { 500 }

sub RootLocations { $_[0]->_cached_roots }

sub All
{
    my $class = shift;
    my %p = validate( @_,
		      { order_by => { type => SCALAR, default => 'parent' },
		      }
		    );

    if ( $p{order_by} eq 'parent' )
    {
        return sort _sort_by_parent $class->all;
    }
    else
    {
        return $class->all;
    }
}

sub LocationsForVendors
{
    my $class = shift;
    my %p = validate( @_,
		      { order_by => { type => SCALAR, default => 'parent' },
		      }
		    );

    my @l;

    foreach my $l ( $class->all )
    {
	next unless $l->can_have_vendors;

	my $root = ($l->ancestors)[0];

	next unless $l->name eq 'Internet' || $root;

	push @l, $l;
    }

    if ( $p{order_by} eq 'parent' )
    {
        return sort _sort_by_parent @l;
    }
    else
    {
        return @l
    }
}

sub _sort_by_parent
{
    my $ap = $a->parent;
    my $bp = $b->parent;

    if ( $ap && $bp )
    {
        my $cmp = lc $ap->name cmp lc $bp->name;

        return $cmp if $cmp;

        return lc $a->name cmp lc $b->name;
    }
    elsif ( $bp && ! $ap )
    {
        return lc $a->name cmp lc $bp->name;
    }
    elsif ( $ap && ! $bp )
    {
        return lc $ap->name cmp lc $b->name;
    }
    else
    {
        return lc $a->name cmp lc $b->name;
    }
}

sub ByVendorCount
{
    my $class = shift;
    my %p = validate( @_,
                      { limit => { type => SCALAR, default => 5 },
                      },
                    );

    my $schema = VegGuide::Schema->Connect();

    my $Vendor_t = $schema->Vendor_t;

    return
        VegGuide::Cursor::LocationAndCount->new
            ( cursor =>
              $Vendor_t->select
                  ( select =>
                    [ $schema->sqlmaker->COUNT( $Vendor_t->vendor_id_c ),
                      $Vendor_t->location_id_c,
                    ],
                    where => [ $Vendor_t->close_date_c, '=', undef ],
                    group_by =>
                    $Vendor_t->location_id_c,
                    order_by =>
                    [ $schema->sqlmaker->COUNT( $Vendor_t->vendor_id_c ),
                      'DESC',
                    ],
                    limit => $p{limit}
                  )
            );
}

{
    my $spec = { name   => SCALAR_TYPE,
                 parent => SCALAR_TYPE( optional => 1 ),
               };

    sub ByNameOrCityName
    {
        my $class = shift;
        my %p     = validate( @_, $spec );

        my $regex = $class->_NameToRegex( $p{name} );

        my $schema = VegGuide::Schema->Connect();

        my ( $lp_join, $lp_order_by, $parent_table ) = $class->LocationAndParentClauses();

        my @where =
            ( '(',
              [ $schema->sqlmaker()->LOWER( $schema->Vendor_t()->city_c() ), 'REGEXP', $regex ],
              'or',
              [ $schema->sqlmaker()->LOWER( $schema->Vendor_t()->localized_city_c() ), 'REGEXP', $regex ],
              'or',
              [ $schema->sqlmaker()->LOWER( $class->table()->name_c() ), 'REGEXP', $regex ],
              'or',
              [ $schema->sqlmaker()->LOWER( $class->table()->localized_name_c() ), 'REGEXP', $regex ],
              ')',
            );

        if ( $p{parent} )
        {
            my $parent = $p{parent};

            if ( length $parent < 3 )
            {
                my $long = first { defined } map { scalar $_->state($parent) } $class->GeoStatesObjects();
                $parent = $long if defined $long;
            }

            my $parent_regex = $class->_NameToRegex($parent);

            push @where,
                ( 'and',
                  '(',
                  [ $schema->sqlmaker()->LOWER( $parent_table->name_c() ), 'REGEXP', $parent_regex ],
                  'or',
                  [ $schema->sqlmaker()->LOWER( $parent_table->localized_name_c() ), 'REGEXP', $parent_regex ],
                  ')',
                );
        }

        return
            $class->cursor
                ( $schema->join
                      ( distinct => $class->table(),
                        join =>
                        [ [ left_outer_join => $schema->tables( 'Location', 'Vendor' ) ],
                          $lp_join,
                        ],
                        where => \@where,
                        order_by => $lp_order_by,
                      )
                );
    }
}

sub name_matches_text
{
    my $self = shift;
    my $text = shift;

    my $regex = $self->_NameToRegex($text);

    return 1 if $self->name() =~ /$regex/i;
}

sub cities_matching_text
{
    my $self = shift;
    my $text = shift;

    my $regex = $self->_NameToRegex($text);

    my $schema = VegGuide::Schema->Connect();

    my @cities =
        $schema->Vendor_t()->function
            ( select => $schema->sqlmaker()->DISTINCT( $schema->Vendor_t->city_c() ),
              where  =>
              [ [ $schema->sqlmaker()->LOWER( $schema->Vendor_t()->city_c() ), 'REGEXP', $regex ],
                [ $schema->Vendor_t()->location_id_c(), '=', $self->location_id() ],
              ]
            );

    push @cities,
        $schema->Vendor_t()->function
            ( select => $schema->sqlmaker()->DISTINCT( $schema->Vendor_t->localized_city_c() ),
              where  =>
              [ [ $schema->sqlmaker()->LOWER( $schema->Vendor_t()->localized_city_c() ), 'REGEXP', $regex ],
                [ $schema->Vendor_t()->location_id_c(), '=', $self->location_id() ],
              ]
            );

    return uniq @cities;
}

{
    my %Cardinal = ( n => 'n|no|north', e => 'e|east', s => 's|so|south', w => 'w|west' );
    my $CardinalRE = eval 'qr/(' . ( join '|', map { "(?:$_)" } values %Cardinal ) . ')/i';

    sub _NameToRegex
    {
        shift;
        my $name = shift;

        my $regex = '';
        if ( $name =~ s/^$CardinalRE\s+// )
        {
            $regex = '^(' . $Cardinal{ lc substr( $1, 0, 1 ) } . ') ';
        }

        if ( $name =~ s/^(st\.?|saint)\s+// )
        {
            $regex = '^(st.?|saint) ';
        }

        $regex .= quotemeta $name;

        return $regex;
    }

}

sub LocationAndParentClauses
{
    shift;

    my $schema = VegGuide::Schema->Connect();

    my $location_alias = $schema->Location_t()->alias();

    my $fk =
        first { ( $_->columns_from() )[0]->name() eq 'parent_location_id' }
        $schema->Location_t()->foreign_keys_by_table( $schema->Location_t() );

    return
        ( [ left_outer_join => $schema->Location_t(), $location_alias, $fk ],
          [ $location_alias->name_c(),
            $schema->Location_t()->name_c(),
          ],
          $location_alias
        );
}

sub AverageVendorCount
{
    my $schema = VegGuide::Schema->Connect();

    my $sql = <<'EOF';
SELECT AVG (vendor_count)
  FROM ( SELECT COUNT(*) AS vendor_count
           FROM Vendor
       GROUP BY location_id
         HAVING vendor_count > 0 ) AS whatever
EOF

    my $dbh = VegGuide::Schema->Connect()->driver()->handle();

    return $dbh->selectrow_arrayref($sql)->[0];
}

sub MedianVendorCount
{
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my $count = $class->LocationsWithVendorsCount();

    my $start = int( $count / 2 );
    my $limit = $count % 2 ? 1 : 2;

    my $sql = <<"EOF";
  SELECT COUNT(*) AS vendor_count
    FROM Vendor
GROUP BY location_id
  HAVING vendor_count > 0
ORDER BY vendor_count
   LIMIT $start, $limit
EOF

    my $dbh = VegGuide::Schema->Connect()->driver()->handle();

    my $vals = $dbh->selectcol_arrayref($sql);

    return ( sum @{$vals} ) / ( scalar @{$vals} );
}

sub BranchLocationCount
{
    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Location_t()->function
            ( select =>
              $schema->sqlmaker->COUNT
                  ( $schema->sqlmaker->DISTINCT
                        ( $schema->Location_t()->parent_location_id_c() ) )
            );
}

sub LeafLocationCount
{
    my $class = shift;

    return $class->Count() - $class->BranchLocationCount();
}

sub LocationsWithVendorsCount
{
    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Vendor_t->function
            ( select =>
              $schema->sqlmaker->COUNT
                  ( $schema->sqlmaker->DISTINCT
                        ( $schema->Vendor_t->location_id_c ) ),
            );
}

sub LocationsWithVendors
{
    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Vendor_t->function
            ( select =>
              $schema->sqlmaker->DISTINCT
                  ( $schema->Vendor_t->location_id_c ),
            );
}

sub CountryCount
{
    my $class = shift;

    return
        $class->table()->row_count
            ( where => [ $class->table()->is_country_c(), '=', 1 ] );
}

sub RecentlyAdded
{
    my $class = shift;
    my %p     = validate( @_,
                          { days  => { type => SCALAR, optional => 1 },
                            limit => { type => SCALAR, optional => 1 },
                          },
                        );

    my %where;
    if ( $p{days} )
    {
        my $since = DateTime->today()->subtract( days => $p{days} );

        $where{where} =
            [ $class->table()->creation_datetime_c(),
              '>=', DateTime::Format::MySQL->format_datetime($since) ];
    }

    my %limit;
    $limit{limit} = $p{limit} if $p{limit};

    return
        $class->cursor
            ( $class->table()->rows_where
                  ( %where,
                    order_by =>
                    [ $class->table()->creation_datetime_c, 'DESC' ],
                    %limit
                  ),
            );
}

sub AllComments
{
    my $schema = VegGuide::Schema->Connect();

    return
        $_[0]->cursor
            ( $schema->join
                  ( select =>
                    [ $schema->tables( 'LocationComment', 'User' ) ],
                    join =>
                    [ $schema->tables( 'Location', 'LocationComment', 'User' ) ],
                    order_by =>
                    [ $schema->LocationComment_t->last_modified_datetime_c, 'DESC',
                    ],
                  )
            );
}

sub USA
{
    my $class = shift;

    return $class->new( name => 'USA' );
}


package VegGuide::Cursor::LocationAndCount;

use base qw(Class::AlzaboWrapper::Cursor);

sub next
{
    my $self = shift;

    my ($count, $location_id) = $self->{cursor}->next
        or return;

    return
        ( $count,
          VegGuide::Location->new
              ( location_id => $location_id )
        );
}


package VegGuide::LocationComment;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper
    ( table => VegGuide::Schema->Schema->LocationComment_t );

use base 'VegGuide::Comment';

sub location { VegGuide::Location->new( location_id => $_[0]->location_id ) }


1;
