
use Test::More tests => 3;
use_ok( Catalyst::Test, 'VegGuide' );
use_ok('VegGuide::Controller::User');

ok( request('user')->is_success );

