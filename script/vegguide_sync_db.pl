#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";

use VegGuide::Config;
use VegGuide::Schema;

sync_backend();
insert_defaults() if grep { $_ eq '--data' } @ARGV;

sub sync_backend {
    my %c = VegGuide::Config->DBConnectParams();
    delete $c{dsn};

    my $schema = VegGuide::Schema->CreateSchema();

    $schema->drop(%c) if grep { $_ eq '--drop' } @ARGV;

    for my $sql ( $schema->sync_backend_sql(%c) ) {
        $sql =~ s/^/  /gm;

        print $sql, "\n";
    }

    $schema->sync_backend(%c);

    eval {
        $schema->driver()
            ->do( sql => 'DROP FUNCTION IF EXISTS WEIGHTED_RATING' );
    };

    $schema->driver()->do( sql => <<'EOF' );
CREATE FUNCTION
  WEIGHTED_RATING (vendor_id INTEGER, min INTEGER, overall_mean FLOAT)
                  RETURNS FLOAT
  DETERMINISTIC
  READS SQL DATA
BEGIN
  DECLARE v_mean FLOAT;
  DECLARE v_count FLOAT;
  DECLARE l_mean FLOAT;

  SELECT AVG(rating), COUNT(rating) INTO v_mean, v_count
    FROM VendorRating
   WHERE VendorRating.vendor_id = vendor_id;

  IF v_count = 0 THEN
    RETURN 0.0;
  END IF;

  RETURN ( v_count / ( v_count + min ) ) * v_mean + ( min / ( v_count + min ) ) * overall_mean;
END;
EOF

    eval {
        $schema->driver()
            ->do( sql => 'DROP FUNCTION IF EXISTS GREAT_CIRCLE_DISTANCE' );
    };

    $schema->driver()->do( sql => <<'EOF' );
CREATE FUNCTION
  GREAT_CIRCLE_DISTANCE ( radius DOUBLE,
                          v_lat DOUBLE, v_long DOUBLE,
                          p_lat DOUBLE, p_long DOUBLE )
                        RETURNS DOUBLE
  DETERMINISTIC
BEGIN

  RETURN (2
          * radius
          * ATAN2( SQRT( @x := ( POW( SIN( ( RADIANS(v_lat) - RADIANS(p_lat) ) / 2 ), 2 )
                                 + COS( RADIANS( p_lat ) ) * COS( RADIANS(v_lat) )
                                 * POW( SIN( ( RADIANS(v_long) - RADIANS(p_long) ) / 2 ), 2 )
                               )
                       ),
                   SQRT( 1 - @x ) )
         );


END;
EOF
}

sub insert_defaults {
    my %Defaults = (
        UserActivityLogType => {
            column => 'type',
            values => [
                'add vendor',
                'update vendor',
                'suggest a change',
                'suggestion accepted',
                'suggestion rejected',
                'add review',
                'update review',
                'delete review',
                'add image',
                'add region',
            ],
        },
        AddressFormat => {
            column => 'format',
            values => [
                'standard',
                'Hungarian',
            ],
        },
        Category => {
            column => 'name',
            values => [
                { name => 'Restaurant',                  display_order => 1 },
                { name => 'Coffee/Tea/Juice',            display_order => 2 },
                { name => 'Bar',                         display_order => 3 },
                { name => 'Food Court or Street Vendor', display_order => 4 },
                { name => 'Grocery/Bakery/Deli',         display_order => 5 },
                { name => 'Caterer',                     display_order => 6 },
                { name => 'General Store',               display_order => 7 },
                { name => 'Organization',                display_order => 8 },
                { name => 'Hotel/B&B', display_order => 10 },
                { name => 'Other',     display_order => 10 },
            ],
        },
        PriceRange => {
            column => 'price_range_id',
            values => [
                {
                    price_range_id => 1, description => '$ - inexpensive',
                    display_order  => 1
                }, {
                    price_range_id => 2, description => '$$ - average',
                    display_order  => 2
                }, {
                    price_range_id => 3, description => '$$$ - expensive',
                    display_order  => 3
                },
            ],
        },
    );

    my $schema = VegGuide::Schema->Connect();

    foreach my $t ( keys %Defaults ) {
        my $table  = $schema->table($t);
        my $column = $table->column( $Defaults{$t}{column} );

        my $x = 1;
        foreach my $val ( @{ $Defaults{$t}{values} } ) {
            my $where_val = ref $val ? $val->{ $column->name } : $val;

            unless (
                $table->function(
                    select => 1,
                    where  => [ $column, '=', $where_val ]
                )
                ) {
                my %insert = ref $val ? %$val : ( $column->name => $val );

                $table->insert( values => \%insert );
            }
        }
    }

    require VegGuide::Locale;
    my $standard = VegGuide::AddressFormat->Standard();

    $schema->driver->do(
        sql =>
            'UPDATE Locale SET address_format_id = ? WHERE address_format_id IN (NULL, 0)',
        bind => $standard->address_format_id,
    );
}
