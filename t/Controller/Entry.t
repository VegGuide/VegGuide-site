
use Test::More tests => 3;
use_ok( Catalyst::Test, 'VegGuide' );
use_ok('VegGuide::Controller::Entry');

ok( request('entry')->is_success );

