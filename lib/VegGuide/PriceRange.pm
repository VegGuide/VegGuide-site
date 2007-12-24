package VegGuide::PriceRange;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema->PriceRange_t );


my %PriceRanges;
my %PriceRangesByName;
my %PriceRangeSymbolsOnly;

BEGIN
{
    %PriceRanges =
        ( map { $_->select('price_range_id') => VegGuide::PriceRange->SUPER::new( object => $_ ) }
          VegGuide::Schema->Connect->PriceRange_t->all_rows->all_rows
        );

    %PriceRangesByName =
        map { $_->description() => $_ } values %PriceRanges;

    %PriceRangeSymbolsOnly =
        map { $_->price_range_id() => ( $_->description =~ /^(\$+)/ ) } values %PriceRanges;
}

sub new
{
    my $class = shift;
    my %p = @_;

    return $PriceRanges{ $p{price_range_id} };
}

sub symbols_only
{
    my $self = shift;

    return $PriceRangeSymbolsOnly{ $self->price_range_id() };
}

sub All
{
    return sort { $a->display_order() <=> $b->display_order() } values %PriceRanges;
}


1;
