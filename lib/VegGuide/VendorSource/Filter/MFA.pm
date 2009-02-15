package VegGuide::VendorSource::Filter::MFA;

use strict;
use warnings;

use Geography::States;
use List::MoreUtils qw( uniq );
use VegGuide::Category;
use VegGuide::Location;
use VegGuide::User;
use VegGuide::Util qw( clean_text string_is_empty );


sub filter
{
    my $class = shift;
    my $items = shift;

    $class->_merge_categories($items);

    my @save;
    for my $item ( @{ $items } )
    {
        next unless $class->_filter_item($item);

        push @save, $item;
    }

    @{ $items } = @save;
}

sub _merge_categories
{
    my $class = shift;
    my $items = shift;

    my @save;
    my %seen;
    for ( my $i = 0; $i < @{ $items }; $i++ )
    {
        clean_text($_) for @{ $items->[$i] }{ 'title', 'address1' };

        my $key =
            ( join "\0",
              map { defined $_ ? $_ : '' }
              @{ $items->[$i] }{ 'title', 'address1' }
            );

        if ( defined $seen{$key} )
        {
            push @{ $items->[ $seen{$key} ]{category} }, @{ $items->[$i]{category} };

            if ( $seen{$key}
                 && $items->[ $seen{$key} ]{city}
                 && $items->[$i]{city}
                 && $items->[ $seen{$key} ]{city} ne $items->[$i]{city}
               )
            {
                warn "Possible duplicate: $items->[$i]{title} in $items->[$i]{city}\n";
            }
        }
        else
        {
            $seen{$key} = $i;

            push @save, $items->[$i];
        }
    }

    @{ $items } = @save;

    for my $item ( @{ $items } )
    {
        $item->{category} = [ uniq @{ $item->{category} } ];
    }
}

{
    my @UnusedKeys = qw( veg-level country latitude longitude );
    sub _filter_item
    {
        my $class = shift;
        my $item  = shift;

        $item->{name} = delete $item->{title};

        $item->{external_unique_id} = delete $item->{'foreign-id'};

        if ( string_is_empty( $item->{'long-description'} )
             || ref $item->{'long-description'} )
        {
            warn "No description at all for $item->{name} ($item->{external_unique_id})\n";
            return;
        }

        if ( length $item->{'long-description'} > 100
             && $item->{'long-description'} =~ s/^([^.]+)\.\s+// )
        {
            $item->{short_description} = $1;
        }

        $item->{short_description} ||= delete $item->{'long-description'};

        my $location = $class->_location_for_item( $item, $class->_state_for_id( $item->{external_unique_id} ) );

        unless ( $location )
        {
            warn "Could not determine location for $item->{name} ($item->{external_unique_id})\n";
            return;
        }

        $item->{location_id} = $location->location_id();
        $item->{region} = $location->parent()->name();

        $item->{category_id} = [ map { $class->_category_id_for($_) } @{ delete $item->{category} } ];

        # XXX - hacky
        $item->{price_range_id} = 2;

        for my $k ( keys %{ $item } )
        {
            my $orig = $k;

            if ( $k =~ s/-/_/g )
            {
                $item->{$k} = delete $item->{$orig};
            }
        }

        $item->{veg_level} = delete $item->{'veg_level_number'};

        delete @{ $item }{@UnusedKeys};

        return 1;
    }
}

sub _state_for_id
{
    my $class = shift;
    my $id    = shift;

    return $1 if $id =~ /^Veg(\w+)\./;

    die "Cannot determine state for $id";
}

{
    my $User = VegGuide::User->new( real_name => 'VegGuide.Org' );
    my $USA = VegGuide::Location->USA();
    my $NJ = VegGuide::Location->new( name => 'New Jersey',
                                      parent_location_id => $USA->location_id(),
                                    );
    my $states = Geography::States->new('USA');


    my %RegionMap = ( # IL
                      ( map { $_ => 'Champaign-Urbana' } qw( Champaign Urbana ) ),
                      ( map { $_ => 'Bloomington-Normal' } qw( Bloomington Normal ) ),

                      # NJ
                      ( map { $_ => 'Cherry Hill Area' }
                        'Cherry Hill', qw( Barrington Collingswood Marlton Merchantville Voorhees ) ),
                      ( map { $_ => 'Mount Laurel' } 'Mt Laurel', 'Mt. Laurel' ),
                      ( map { $_ => 'Mount Holly' } 'Mt Holly', 'Mt. Holly' ),
                      ( 'Hohokus' => 'Ho-Ho-Kus' ),
                      ( 'Ramsey' => 'Ramsey Area' ),
                      ( map { $_ => 'Parsippany Area' } qw( Parsippany Wayne ) ),
                      ( map { $_ => 'Hackensack Area' } qw( Hackensack Rutherford Teaneck ) ),
                      'ALL NJ - CATERING' => $NJ,

                      # NC
                      ( map { $_ => 'Triangle Area' } qw( Raleigh Durham Cary ), 'Chapel Hill' ),
                    );

    sub _location_for_item
    {
        my $class = shift;
        my $item  = shift;
        my $state = shift;

        return if string_is_empty( $item->{region} );

        if ( length $state == 2 )
        {
            $state = $states->state($state);
        }

        my $parent = VegGuide::Location->new( name               => $state,
                                              parent_location_id => $USA->location_id(),
                                            );

        unless ($parent)
        {
            warn "No location for state: $state\n";
            return;
        }

        if ( $item->{region} =~ /^Philadelphia/ )
        {
            $item->{region} = 'Philadelphia Metro';
        }

        if ( $RegionMap{ $item->{region} } )
        {
            my $region = $RegionMap{ $item->{region} };
            return $region if ref $region;

            $item->{region} = $region;
        }

        my $location = VegGuide::Location->new( name               => $item->{region},
                                                parent_location_id => $parent->location_id(),
                                              );

        unless ($location)
        {
            warn "Making new location $item->{region}, $state\n"
                if VegGuide::VendorSource::DEBUG();

            $location = VegGuide::Location->create( name               => $item->{region},
                                                    parent_location_id => $parent->location_id(),
                                                    user_id            => $User->user_id(),
                                                  );
        }

        return $location;
    }
}

{
    my %Categories = ( Restaurant   => VegGuide::Category->Restaurant()->category_id(),
                       Grocery      => VegGuide::Category->GroceryBakeryDeli()->category_id(),
                       Organization => VegGuide::Category->Organization()->category_id(),
                     );

    sub _category_id_for
    {
        my $class    = shift;
        my $category = shift;

        return $Categories{$category} || ();
    }
}

1;
