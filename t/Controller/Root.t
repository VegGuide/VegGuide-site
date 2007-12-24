
use Test::More tests => 3;
use_ok( Catalyst::Test, 'VegGuide' );
use_ok('VegGuide::Controller::Root');

ok( request('root')->is_success );

