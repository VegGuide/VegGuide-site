use strict;
use warnings;

use Test::More;

use VegGuide::Schema;

{
    my $schema = VegGuide::Schema->Schema();
    isa_ok( $schema, 'Alzabo::Runtime::Schema' );
    can_ok( $schema,             'Vendor_t' );
    can_ok( $schema->Vendor_t(), 'vendor_id_c' );
}

{
    my $schema = VegGuide::Schema->Connect();

    isa_ok( $schema, 'Alzabo::Runtime::Schema' );
    ok( $schema->driver()->handle(), 'schema is connected to database' );

    my $handle = $schema->driver()->handle();

    local $$ = $$ + 1;

    $schema = VegGuide::Schema->Connect();

    isnt(
        $handle, $schema->driver()->handle(),
        'automatically reconnects when pid changes'
    );
}

done_testing();
