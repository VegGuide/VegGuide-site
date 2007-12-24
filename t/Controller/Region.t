
use Test::More tests => 3;
use_ok( Catalyst::Test, 'VegGuide' );
use_ok('VegGuide::Controller::Region');

ok( request('region')->is_success );

