package VegGuide::VendorSource::Filter::MFA;

use strict;
use warnings;

use Geography::States;
use List::MoreUtils qw( uniq );
use VegGuide::Category;
use VegGuide::Location;
use VegGuide::User;
use VegGuide::Util qw( clean_text string_is_empty );

sub filter {
    my $class = shift;
    my $items = shift;

    $class->_merge_categories($items);

    my @save;
    for my $item ( @{$items} ) {
        next unless $class->_filter_item($item);

        push @save, $item;
    }

    @{$items} = @save;
}

sub _merge_categories {
    my $class = shift;
    my $items = shift;

    my @save;
    my %seen;
    for ( my $i = 0; $i < @{$items}; $i++ ) {
        clean_text($_) for @{ $items->[$i] }{ 'title', 'address1' };

        my $key = (
            join "\0",
            map { defined $_ ? $_ : '' }
                @{ $items->[$i] }{ 'title', 'address1' }
        );

        if ( defined $seen{$key} ) {
            push @{ $items->[ $seen{$key} ]{category} },
                @{ $items->[$i]{category} };

            if (   $seen{$key}
                && $items->[ $seen{$key} ]{city}
                && $items->[$i]{city}
                && $items->[ $seen{$key} ]{city} ne $items->[$i]{city} ) {
                warn
                    "Possible duplicate: $items->[$i]{title} in $items->[$i]{city}\n";
            }
        }
        else {
            $seen{$key} = $i;

            push @save, $items->[$i];
        }
    }

    @{$items} = @save;

    for my $item ( @{$items} ) {
        $item->{category} = [ uniq @{ $item->{category} } ];
    }
}

{
    my @UnusedKeys = qw( veg-level country latitude longitude );

    sub _filter_item {
        my $class = shift;
        my $item  = shift;

        $item->{name} = delete $item->{title};

        $item->{name} =~ s/\Q&#8206;//g;

        $item->{external_unique_id} = delete $item->{'foreign-id'};

        if ( string_is_empty( $item->{'long-description'} )
            || ref $item->{'long-description'} ) {
            warn
                "No description at all for $item->{name} ($item->{external_unique_id})\n";
            return;
        }

        if ( length $item->{'long-description'} > 100
            && $item->{'long-description'} =~ s/^([^.]+)\.\s+// ) {
            $item->{short_description} = $1;
        }

        $item->{short_description} ||= delete $item->{'long-description'};

        $item->{category_id} = [ map { $class->_category_id_for($_) }
                @{ delete $item->{category} } ];

        # XXX - hacky
        $item->{price_range_id} = 2;

        for my $k ( keys %{$item} ) {
            my $orig = $k;

            if ( $k =~ s/-/_/g ) {
                $item->{$k} = delete $item->{$orig};
            }
        }

        $item->{veg_level} = delete $item->{'veg_level_number'};

        delete @{$item}{@UnusedKeys};

        return 1;
    }
}

{
    my $User = VegGuide::User->new( real_name => 'VegGuide.org' );
    my $USA  = VegGuide::Location->USA();
    my $NJ   = VegGuide::Location->new(
        name               => 'New Jersey',
        parent_location_id => $USA->location_id(),
    );
    my $states = Geography::States->new('USA');

    my %RegionMap = (
        Illinois => {
            ( map { lc $_ => 'Champaign-Urbana' } qw( Champaign Urbana ) ),
            (
                map { lc $_ => 'Bloomington-Normal' } qw( Bloomington Normal )
            ),
        },

        'New Jersey' => {
            (
                map { lc $_ => 'Cherry Hill Area' } 'Cherry Hill',
                qw( Barrington Collingswood Marlton Merchantville Voorhees )
            ),
            ( map { lc $_ => 'Mount Laurel' } 'Mt Laurel', 'Mt. Laurel' ),
            ( map { lc $_ => 'Mount Holly' } 'Mt Holly',   'Mt. Holly' ),
            ( lc 'Hohokus'    => 'Ho-Ho-Kus' ),
            ( lc 'Lindenwald' => 'Lindenwold' ),
            ( lc 'Ramsey'     => 'Ramsey Area' ),
            ( map { lc $_ => 'Parsippany Area' } qw( Parsippany Wayne ) ),
            (
                map { lc $_ => 'Hackensack Area' }
                    qw( Hackensack Rutherford Teaneck )
            ),
            'all nj - catering' => $NJ,
        },

        'North Carolina' => {
            (
                map { lc $_ => 'Triangle Area' } qw( Raleigh Durham Cary ),
                'Chapel Hill'
            ),
            'Mathews' => 'Matthews',
        },

        Indiana => { ( lc 'Mishawaka' => 'South Bend' ), },
    );

    sub _location_for_item {
        my $class = shift;
        my $item  = shift;

        my $state = $class->_state_for_item($item);

        return if string_is_empty( $item->{region} );

        if ( length $state == 2 ) {
            $state = $states->state($state);
        }

        my $parent = VegGuide::Location->new(
            name               => $state,
            parent_location_id => $USA->location_id(),
        );

        unless ($parent) {
            warn "No location for state: $state\n";
            return;
        }

        my $region = $item->{region};

        if ( $item->{region} =~ /^Philadelphia/ ) {
            $region = 'Philadelphia Metro';
        }

        if ( $RegionMap{ $parent->name() }{ lc $item->{region} } ) {
            $region = $RegionMap{ $parent->name() }{ lc $item->{region} };
            return $region if ref $region;
        }

        # apparently the NJ folks thought it'd "stand out more" if the
        # regions were in all caps - fucking brilliant
        if ( $parent->name() eq 'New Jersey' ) {
            $region = join q{ }, map { ucfirst lc } split /\s+/, $region;
        }

        my $location = VegGuide::Location->new(
            name               => $region,
            parent_location_id => $parent->location_id(),
        );

        unless ($location) {
            warn "Making new location $region, $state\n"
                if VegGuide::VendorSource::DEBUG();

            $location = VegGuide::Location->create(
                name               => $region,
                parent_location_id => $parent->location_id(),
                user_id            => $User->user_id(),
            );
        }

        return $location;
    }
}

sub _state_for_item {
    my $class = shift;
    my $item  = shift;

    return $1 if $item->{external_unique_id} =~ /^Veg(\w+)\./;

    die "Cannot determine state for $item->{external_unique_id}";
}

{
    my %Categories = (
        Restaurant => VegGuide::Category->Restaurant()->category_id(),
        Grocery    => VegGuide::Category->GroceryBakeryDeli()->category_id(),
        Organization => VegGuide::Category->Organization()->category_id(),
    );

    sub _category_id_for {
        my $class    = shift;
        my $category = shift;

        return $Categories{$category} || ();
    }
}

1;
