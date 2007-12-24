use strict;
use warnings;

use Test::More tests => 4;

use VegGuide::Keywords;


my $kw = VegGuide::Keywords->new();
$kw->add('thing');

my @kw = $kw->all();
is( scalar @kw, 1, 'one keyword returned' );
is( $kw[0], 'thing', 'first keyword is thing' );

$kw->add('blue');

@kw = $kw->all();
is( scalar @kw, 2, 'two keywords returned' );
is( $kw[1], 'blue', 'second keyword is blue' );
