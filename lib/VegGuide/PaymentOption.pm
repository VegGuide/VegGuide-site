package VegGuide::PaymentOption;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema->PaymentOption_t );

use VegGuide::Validate qw( validate_with SCALAR );

sub _new_row {
    my $class = shift;
    my %p     = validate_with(
        params => \@_,
        spec   => {
            name => { type => SCALAR, optional => 1 },
        },
        allow_extra => 1,
    );

    my $schema = VegGuide::Schema->Connect();

    my $user;
    if ( $p{name} ) {
        my @where;
        push @where, [ $schema->PaymentOption_t->name_c, '=', $p{name} ];

        return $schema->PaymentOption_t->one_row( where => \@where );
    }

    return;
}

sub image_name {
    my $self = shift;

    my $name = lc $self->name;

    $name =~ s/[^\w]/_/g;

    return $name;
}

1;
