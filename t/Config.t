use strict;
use warnings;

use Test::More;

use Sys::Hostname ();
use VegGuide::Config;

my $is_prod
    = Sys::Hostname::hostname() =~ /(?:vegguide|vegcrew|satyr)/ ? 1 : 0;

{
    my $has_debug
        = grep { $_ eq '-Debug' } VegGuide::Config->CatalystImports() ? 1 : 0;
    my $expect = $is_prod ? 1 : 0;
    is( $has_debug, $expect, 'check for presence of -Debug in imports' );
}

{
    my %cat_config = VegGuide::Config->CatalystConfig();
    ok( $cat_config{session},       'defines session config' );
    ok( $cat_config{dbi},           'defines dbi config' );
    ok( $cat_config{authen_cookie}, 'defines authen cookie config' );
}

{
    my %dbi_config = VegGuide::Config->DBConnectParams();
    ok( $dbi_config{user}, 'defines user for dbi' );
}

{
    my %mason_config = VegGuide::Config->MasonConfig();
    ok( -d $mason_config{comp_root}, 'defines mason comp_root' );
    ok( -d $mason_config{data_dir},  'defines mason data_dir' );
}

{
    my $forgot_pw_secret = VegGuide::Config->ForgotPWSecret();
    ok( defined $forgot_pw_secret, 'forgot pw secret is defined' );
    ok( length $forgot_pw_secret, 'forgot pw secret is not an empty string' );
}

{
    my $mac_secret = VegGuide::Config->MACSecret();
    ok( defined $mac_secret, 'mac secret is defined' );
    ok( length $mac_secret,  'mac secret is not an empty string' );
}

done_testing();
