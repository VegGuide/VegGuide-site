package VegGuide::Attribute;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema()->Attribute_t() );


my %Attributes;
my %AttributesByName;

BEGIN
{
    %Attributes =
        ( map { $_->select('attribute_id') => VegGuide::Attribute->SUPER::new( object => $_ ) }
          VegGuide::Schema->Connect()->Attribute_t()->all_rows()->all_rows()
        );

    %AttributesByName =
        map { $_->name() => $_ } values %Attributes;
}

sub All
{
    return map { $AttributesByName{$_} } sort keys %AttributesByName;
}


1;
