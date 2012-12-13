package Test::VegGuide::DB;

use strict;
use warnings;
use autodie;

BEGIN {
    my $db_name = 'VegGuideTest' . '_user_' . scalar getpwuid($>);

    use Test::DBIx::Class {
        -schema_class => 'VegGuide::DB::Schema',
        -connect_info => [ 'dbi:mysql:database=' . $db_name, 'root', undef ],

    };
}
