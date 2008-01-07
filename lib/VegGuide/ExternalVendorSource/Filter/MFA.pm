package VegGuide::ExternalVendorSource::Filter::MFA;

use strict;
use warnings;

use VegGuide::Category;
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

        delete @{ $item }{@UnusedKeys};

        $item->{name} = delete $item->{title};

        $item->{veg_level} = delete $item->{'veg-level-number'};

        $item->{external_unique_id} = delete $item->{'foreign-id'};

        $item->{state} = $class->_state_for_id( $item->{external_unique_id} );

        $item->{category_id} = [ map { $class->_category_id_for($_) } @{ delete $item->{category} } ];

        for my $k ( keys %{ $item } )
        {
            my $orig = $k;

            if ( $k =~ s/-/_/g )
            {
                $item->{$k} = delete $item->{$orig};
            }
        }
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
