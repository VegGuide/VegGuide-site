package VegGuide::Search::Vendor;

use strict;
use warnings;

use base 'VegGuide::Search';

use URI::FromHash qw( uri );
use VegGuide::Validate
    qw( validate SCALAR_TYPE SCALAR_OR_ARRAYREF_TYPE ARRAYREF_TYPE BOOLEAN_TYPE );


{
    # This is an array to preserve the order of the key names, so they
    # match the order in the filtering UI.
    my @SearchParams =
        ( category_id              => SCALAR_OR_ARRAYREF_TYPE( default => [] ),
          cuisine_id               => SCALAR_OR_ARRAYREF_TYPE( default => [] ),
          veg_level                => SCALAR_TYPE( default             => undef ),
          allows_smoking           => BOOLEAN_TYPE( default            => undef ),
          is_wheelchair_accessible => BOOLEAN_TYPE( default            => undef ),
          rating                   => SCALAR_TYPE( default             => undef ),
          open_for                 => SCALAR_TYPE( default             => undef ),
          neighborhood             => SCALAR_OR_ARRAYREF_TYPE( default => [] ),
          attribute_id             => SCALAR_OR_ARRAYREF_TYPE( default => [] ),
          accepts_reservations     => BOOLEAN_TYPE( default            => undef ),
          price_range_id           => SCALAR_TYPE( default             => undef ),
          city                     => SCALAR_TYPE( default             => undef ),
          days                     => SCALAR_TYPE( default             => undef ),
          mappable_only            => BOOLEAN_TYPE( default            => 0 ),
        );

    my @SearchKeys   = grep { ! ref } @SearchParams;

    sub SearchParams { return @SearchParams }

    sub SearchKeys { return @SearchKeys }
}

for my $key ( __PACKAGE__->SearchKeys() )
{
    my $sub = sub { return unless defined $_[0]->{$key};
                    return $_[0]->{$key}; };

    no strict 'refs';
    *{$key} = $sub;
}

sub delete
{
    my $self = shift;

    delete @{ $self }{@_};

    $self->_process_sql_query();
}

sub delete_all
{
    my $self = shift;

    $self->delete( $self->filter_names() );
}

sub add
{
    my $self = shift;
    my %p    = validate( @_, { $self->SearchParams() });

    %{ $self } = ( %{ $self }, %p );

    $self->_process_sql_query();
}

sub _process_sql_query
{
    my $self = shift;

    for my $k ( qw( category_id cuisine_id attribute_id ) )
    {
        my $class = "VegGuide::\u$k";
        $class =~ s/_id$//;

        $self->{$k} =
            [ grep { defined && length && $class->IsValidId($_) }
              ref $self->{$k} ? @{ $self->{$k} } : $self->{$k} ];
    }

    $self->{neighborhood} =
        [ grep { defined && length }
          ref $self->{neighborhood} ? @{ $self->{neighborhood} } : $self->{neighborhood} ];

    $self->{join}         = [];
    $self->{where}        = [];
    $self->{descriptions} = {};
    $self->{path_query}   = {};

    push @{ $self->{where} }, VegGuide::Vendor->CloseCutoffWhereClause()
        if $self->_exclude_closed_vendors();

    if ( $self->{mappable_only} )
    {
        push @{ $self->{where} }, VegGuide::Vendor->IsMappableWhereClause();
    }

    $self->$_() for grep { $self->can($_) } map { ("_$_") } $self->SearchKeys();
}

sub _exclude_closed_vendors { 1 }

sub _category_id
{
    my $self = shift;

    return unless @{ $self->{category_id} };

    push @{ $self->{join} },
        [ VegGuide::Schema->Schema()->tables( 'Vendor', 'VendorCategory' ) ];

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->VendorCategory_t->category_id_c,
          'IN', @{ $self->{category_id} } ];

    my @names =
        ( map { lc VegGuide::Category->new( category_id => $_ )->plural_name() }
          @{ $self->{category_id} } );

    if ( @names == 1 )
    {
        $self->{descriptions}{category_id}{long} = "which are $names[0].";
    }
    elsif ( @names == 2)
    {
        $self->{descriptions}{category_id}{long} =
            "which are $names[0] or $names[1].";
    }
    else
    {
        my $last = pop @names;
        my $desc = 'which are ';

        $desc .= join ', ', @names;
        $desc .= ", or $last";

        $self->{descriptions}{category_id}{long} = $desc;
    }

    $self->{descriptions}{category_id}{short} = join ', ', @names;

    $self->{path_query}{category_id} = $self->{category_id};
}

sub _cuisine_id
{
    my $self = shift;

    return unless @{ $self->{cuisine_id} };

    push @{ $self->{join} },
        [ VegGuide::Schema->Schema()->tables( 'Vendor', 'VendorCuisine' ) ];

    my @c = map { VegGuide::Cuisine->new( cuisine_id => $_ ) } @{ $self->{cuisine_id} };

    my %all_ids = map { $_ => 1 } map { ( $_->descendant_ids, $_->cuisine_id ) } @c;

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->VendorCuisine_t->cuisine_id_c,
          'IN', keys %all_ids ];

    my @names = map { $_->name } @c;

    if ( @names == 1 )
    {
        $self->{descriptions}{cuisine_id}{long} = " which serve $names[0] food.";
    }
    else
    {
        my $desc = " which serve at least one of the following cuisines: ";
        $desc .= join ', ', sort { $a cmp $b } @names;
        $self->{descriptions}{cuisine_id}{long} = $desc;
    }

    $self->{descriptions}{cuisine_id}{short} = join ', ', @names;

    $self->{path_query}{cuisine_id} = $self->{cuisine_id};
}

sub _neighborhood
{
    my $self = shift;

    my @n = @{ $self->{neighborhood} };
    return unless @n;

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->neighborhood_c, 'IN', @n ];

    if ( @n == 1 )
    {
        $self->{descriptions}{neighborhood}{long} = " in the $n[0] neighborhood.";
    }
    elsif  ( @n == 2 )
    {
        $self->{descriptions}{neighborhood}{long} = " in the $n[0] or $n[1] neighborhoods.";
    }
    else
    {
        my $desc = " in one of these neighborhoods: ";
        my $last = pop @n;
        $desc .= join ', ', @n;
        $desc .= ', or ' . $last;

        $self->{descriptions}{neighborhood}{long} = $desc;

        push @n, $last;
    }

    $self->{descriptions}{neighborhood}{short} = join ', ', @n;

    $self->{path_query}{neighborhood} = \@n;
}

sub _city
{
    my $self = shift;

    return unless grep { defined && length } $self->{city};

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->city_c, 'LIKE', "%$self->{city}%" ];

    $self->{descriptions}{city}{long} = qq| in a city with a name like "$self->{city}".|;
    $self->{descriptions}{city}{short} = $self->{city};

    $self->{path_query}{city} = $self->{city};
}

sub _veg_level
{
    my $self = shift;

    return unless $self->{veg_level};

    if ( $self->{veg_level} == 2 )
    {
        push @{ $self->{where} },
            ( '(',
              [ VegGuide::Schema->Schema()->Vendor_t->veg_level_c, '=', 2 ],
              'or',
              [ VegGuide::Schema->Schema()->Vendor_t->veg_level_c, '>=', 4 ],
              ')',
            );
    }
    else
    {
        push @{ $self->{where} },
            [ VegGuide::Schema->Schema()->Vendor_t->veg_level_c, '>=', $self->{veg_level} ];
    }

    $self->{descriptions}{veg_level}{long} =
        'which are at least ' . VegGuide::Vendor->VegLevelDescription( $self->{veg_level} );

    $self->{descriptions}{veg_level}{short} =
        VegGuide::Vendor->VegLevelDescription( $self->{veg_level} );

    $self->{path_query}{veg_level} = $self->{veg_level};
}

# don't throw an error, just do nothing
sub _open_for { }

sub _allows_smoking
{
    my $self = shift;

    return unless defined $self->{allows_smoking};

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->allows_smoking_c, '=',
          $self->{allows_smoking} ? 1 : 0 ];

    if ( $self->{allows_smoking} )
    {
        $self->{descriptions}{allows_smoking}{long} = 'which allow smoking';
        $self->{descriptions}{allows_smoking}{short} = 'allowed';
    }
    else
    {
        $self->{descriptions}{allows_smoking}{long} = 'which are smoke-free';
        $self->{descriptions}{allows_smoking}{short} = 'not allowed';
    }

    $self->{path_query}{allows_smoking} = $self->{allows_smoking};
}

sub _accepts_reservations
{
    my $self = shift;

    return unless $self->{accepts_reservations};

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->accepts_reservations_c, '=', 1 ];

    $self->{descriptions}{accepts_reservations}{long} = 'which accept reservations';
    $self->{descriptions}{accepts_reservations}{short} = 'yes';

    $self->{path_query}{accepts_reservations} = 1;
}

sub _is_wheelchair_accessible
{
    my $self = shift;

    return unless $self->{is_wheelchair_accessible};

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->is_wheelchair_accessible_c, '=', 1 ];

    $self->{descriptions}{is_wheelchair_accessible}{long} = 'which are wheelchair-accessible';
    $self->{descriptions}{is_wheelchair_accessible}{short} = 'yes';

    $self->{path_query}{is_wheelchair_accessible} = 1;
}

sub _price_range_id
{
    my $self = shift;

    return unless grep { defined && length } $self->{price_range_id};

    my $range = VegGuide::PriceRange->new( price_range_id => $self->{price_range_id} );

    return unless $range;

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t()->price_range_id_c(),
          '=', $range->price_range_id() ];

    my $desc = 'which have ' . $range->description() . ' prices';

    $self->{descriptions}{price_range_id}{long} = $desc;
    $self->{descriptions}{price_range_id}{short} = lc $range->description;

    $self->{path_query}{price_range_id} = $self->{price_range_id};
}

sub _attribute_id
{
    my $self = shift;

    return unless @{ $self->{attribute_id} };

    my @names =
        ( sort
          map { VegGuide::Attribute->new( attribute_id => $_ )->name }
          @{ $self->{attribute_id} } );

    push @{ $self->{where} }, '(';

    foreach my $id ( @{ $self->{attribute_id} } )
    {
        my $alias = VegGuide::Schema->Schema()->VendorAttribute_t->alias;
        push @{ $self->{join} }, [ VegGuide::Schema->Schema()->Vendor_t, $alias ];

        push @{ $self->{where} }, [ $alias->attribute_id_c, '=', $id ];
    }
    push @{ $self->{where} }, ')';

    if ( @names == 1 )
    {
        $self->{descriptions}{attribute_id}{long} =
            qq|which have the feature "$names[0]".|;
    }
    else
    {
        my $desc = 'which have the following features: ';

        if ( @names == 2 )
        {
            $desc .= join ' and ', @names;
        }
        else
        {
            my $last = pop @names;

            $desc .= join ', ', @names;
            $desc .= ", and $last.";
        }

        $self->{descriptions}{attribute_id}{long} = $desc;
    }

    $self->{descriptions}{attribute_id}{short} = join ', ', @names;

    $self->{path_query}{attribute_id} = $self->{attribute_id};
}

sub _rating
{
    my $self = shift;

    return unless $self->{rating};

    my @ids = $self->_vendor_ids_for_rating;

    # Using 0 if there are no ids forces future selects to fail.
    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->vendor_id_c, 'IN',
          @ids ? @ids : 0
        ];

    $self->{descriptions}{rating}{long} = " with a rating of at least $self->{rating}.";
    $self->{descriptions}{rating}{short} = "at least $self->{rating}";

    $self->{path_query}{rating} = $self->{rating};
}

sub _days
{
    my $self = shift;

    return unless $self->{days};

    my $since = DateTime->now->subtract( days => $self->{days} );

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->creation_datetime_c, '>=',
          DateTime::Format::MySQL->format_datetime($since) . ' 00:00:00' ];

    my $days_text = $self->{days} == 1 ? 'day' : "$self->{days} days";

    $self->{descriptions}{days}{long} = "which were added within the last $days_text.";
    $self->{descriptions}{days}{short} = "less than $days_text old";

    $self->{path_query}{days} = $self->{days};
}

{
    my $spec = { order_by   => SCALAR_TYPE( default => undef ),
                 sort_order => SCALAR_TYPE( default => 'ASC' ),
                 page       => SCALAR_TYPE( default => 1 ),
                 limit      => SCALAR_TYPE( default => 20 ),
               };
    sub set_cursor_params
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        $p{order_by} ||= $self->_default_order_by();

        $self->{cursor_params} = \%p;
    }
}

sub vendors
{
    my $self = shift;

    my %p = $self->cursor_params();

    my $page = delete $p{page} || 1;
    $p{start} = ( $page - 1 ) * ( $p{limit} || 20 );

    return $self->_cursor(%p);
}

sub long_descriptions
{
    my $self = shift;

    return map { $self->{descriptions}{$_}{long} } $self->filter_names();
}

sub short_descriptions
{
    my $self = shift;

    return map { $self->{descriptions}{$_}{short} } $self->filter_names();
}

sub has_filters
{
    return scalar $_[0]->long_descriptions();
}

sub filter_names
{
    my $self = shift;

    return grep { $self->{descriptions}{$_} } $self->SearchKeys();
}

sub filter_description
{
    my $self = shift;
    my $name = shift;

    return $self->{descriptions}{$name}{long};
}

sub _path_query
{
    my $self = shift;

    my $uri = uri( path => '/', query => $self->{path_query} );

    return $1
        if $uri =~ /\?(.*)$/;

    return '';
}

sub has_addresses
{
    return 1;
}

sub has_mappable_vendors
{
    my $self = shift;

    if ( $self->{mappable_only} )
    {
        return $self->count();
    }
    else
    {
        my $clone = $self->clone();
        $clone->{mappable_only} = 1;

        $clone->_process_sql_query();

        return $clone->count();
    }
}

{
    my %DefaultOrder = ( name     => 'ASC',
                         city     => 'ASC',
                         rating   => 'DESC',
                         how_veg  => 'DESC',
                         price    => 'ASC',
                         distance => 'ASC',
                       );
    sub DefaultSortOrder
    {
        my $class = shift;
        my $order_by = shift;

        die "Invalid order by ($order_by)"
            unless $DefaultOrder{$order_by};

        return $DefaultOrder{$order_by};
    }
}


1;
