package VegGuide::Category;

use strict;
use warnings;

use Lingua::EN::Inflect qw( PL );
use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema()->Category_t() );


my %Categories;
my %CategoriesByName;

BEGIN
{
    %Categories =
        ( map { $_->select('category_id') => VegGuide::Category->SUPER::new( object => $_ ) }
          VegGuide::Schema->Connect->Category_t->all_rows->all_rows
        );

    %CategoriesByName =
        map { $_->name => $_ } values %Categories;
}

sub new
{
    my $class = shift;
    my %p = @_;

    return $Categories{ $p{category_id} };
}

sub plural_name
{
    return PL( $_[0]->name() );
}

sub All
{
    return sort { $a->display_order <=> $b->display_order } values %Categories;
}

sub Restaurant
{
    return $CategoriesByName{Restaurant};
}

sub GroceryBakeryDeli
{
    return $CategoriesByName{'Grocery/Bakery/Deli'};
}

sub Bar
{
    return $CategoriesByName{Bar};
}

sub CoffeeTeaJuice
{
    return $CategoriesByName{'Coffee/Tea/Juice'};
}

sub Organization
{
    return $CategoriesByName{Organization};
}


1;
