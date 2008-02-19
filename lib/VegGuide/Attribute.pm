package VegGuide::Attribute;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema()->Attribute_t() );

use VegGuide::Validate qw( validate_with SCALAR );


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

    my $user;
    if ( $p{name} )
    {
	my @where;
	push @where,
	    [ $schema->Attribute_t->name_c, '=', $p{name} ];

	return $schema->Attribute_t->one_row( where => \@where );
    }

    return;
}


1;
