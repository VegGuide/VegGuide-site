package VegGuide::AddressFormat;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema->AddressFormat_t );

use VegGuide::Validate qw( validate validate_with SCALAR );

sub _new_row {
    my $class = shift;
    my %p     = validate_with(
        params => \@_,
        spec   => {
            format => { type => SCALAR, optional => 1 },
        },
    );

    if ( $p{format} ) {
        my @where = [ $class->table->format_c, '=', $p{format} ];

        return $class->table->one_row( where => \@where );
    }

    return;
}

sub All {
    my $class = shift;

    return $class->cursor(
        $class->table->all_rows(
            order_by => $class->table->address_format_id_c
        )
    );
}

sub Standard { $_[0]->new( format => 'standard' ) }

1;
