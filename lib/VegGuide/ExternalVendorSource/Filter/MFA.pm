package VegGuide::ExternalVendorSource::Filter::MFA;

use strict;
use warnings;

use VegGuide::Category;
use VegGuide::Location;
use VegGuide::User;
use VegGuide::Util qw( clean_text );


sub filter
{
    my $class = shift;
    my $items = shift;

    $class->_merge_categories($items);

    $class->_filter_item($_) for @{ $items };
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
        }
        else
        {
            $seen{$key} = $i;

            push @save, $items->[$i];
        }
    }

    @{ $items } = @save;
}

{
    my @UnusedKeys = qw( veg-level country latitude longitude );
    sub _filter_item
    {
        my $class = shift;
        my $item  = shift;

        if ( length $item->{'long-description'} > 100
             && $item->{'long-description'} =~ s/^([^.]+)\.\s+// )
        {
            $item->{short_description} = $1;
        }

        $item->{short_description} ||= delete $item->{'long-description'};

        $item->{name} = delete $item->{title};

        $item->{veg_level} = delete $item->{'veg-level-number'};

        $item->{external_unique_id} = delete $item->{'foreign-id'};

        my $location = $class->_location_for_item( $item, $class->_state_for_id( $item->{external_unique_id} ) );

        if ($location)
        {
            $item->{location_id} = $location->location_id();
            $item->{region} = $location->parent()->name();
        }

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

        delete @{ $item }{@UnusedKeys};
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

    sub _location_for_item
    {
        my $class = shift;
        my $item  = shift;
        my $state = shift;

        my $parent = VegGuide::Location->new( name               => $state,
                                              parent_location_id => $USA->location_id(),
                                            );

        unless ($parent)
        {
            warn "No location for state: $state\n";
            return;
        }

        my $location = VegGuide::Location->new( name               => $item->{region},
                                                parent_location_id => $parent->location_id(),
                                              );

        unless ($location)
        {
            warn "Making new location $item->{region}, $state\n"
                if VegGuide::ExternalVendorSource::DEBUG();

            $location = VegGuide::Location->create( name               => $item->{region},
                                                    parent_location_id => $parent->location_id(),
                                                    user_id            => $User->user_id(),
                                                  );
        }

        return $location;
    }
}

{
    my %Categories = ( Restaurant => VegGuide::Category->Restaurant()->category_id(),
                       Grocery    => VegGuide::Category->GroceryBakeryDeli()->category_id(),
                     );

    sub _category_id_for
    {
        my $class    = shift;
        my $category = shift;

        return $Categories{$category} || ();
    }
}

1;
