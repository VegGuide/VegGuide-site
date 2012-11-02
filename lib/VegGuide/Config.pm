package VegGuide::Config;

use strict;
use warnings;

use Cwd ();
use DateTime;
use File::Basename qw( dirname );
use File::Slurp qw( read_file );
use File::Spec;
use Sys::Hostname qw( hostname );

{
    my $Hostname = hostname();
    my $IsProd   = $Hostname eq 'vegguide.org' ? 1 : 0;
    my $IsTest   = $Hostname =~ /test\.vegguide|test-install|satyr/;

    sub Hostname { return $Hostname }

    sub IsProduction { return $IsProd || $IsTest }

    sub IsTest { return $IsTest }
}

{
    my @StandardImports = qw(
        AuthenCookie
        +VegGuide::Plugin::ErrorHandling
        +VegGuide::Plugin::FixupURI
        +VegGuide::Plugin::InOutEncoding
        +VegGuide::Plugin::ResponseAttributes
        DR::Session
        Session::State::URI
        +VegGuide::Plugin::Session::Store::VegGuide
        +VegGuide::Plugin::User
        Cache
        Cache::Store::FastMmap
        Log::Dispatch
        RedirectAndDetach
        SubRequest
    );

    my @Imports;

    sub CatalystImports {
        return @Imports if @Imports;

        @Imports = @StandardImports;
        push @Imports, 'Static::Simple'
            unless __PACKAGE__->IsProduction() || __PACKAGE__->Profiling();

        push @Imports, 'StackTrace'
            unless __PACKAGE__->IsProduction() || __PACKAGE__->Profiling();

        return @Imports;
    }
}

{
    my @Profilers = qw( Devel/DProf.pm
        Devel/FastProf.pm
        Devel/NYTProf.pm
        Devel/Profile.pm
        Devel/Profiler.pm
        Devel/SmallProf.pm
    );

    my $Profiling = grep { $INC{$_} } @Profilers;

    sub Profiling {
        return $Profiling;
    }
}

{
    my @Roles = qw( VegGuide::Role::Tabs
    );

    sub CatalystRoles {
        return @Roles;
    }
}

sub VarLibDir {
    my $class = shift;

    return
          $class->IsProduction() ? '/var/lib/vegguide'
        : $ENV{HARNESS_ACTIVE}   ? dirname( $INC{'VegGuide/Config.pm'} )
        . '/../../t/share'
        : File::Spec->catdir(
        __PACKAGE__->_HomeDir(),
        '.vegguide',
        'var',
        'lib',
        );
}

sub ShareDir {
    my $class = shift;

    return '/usr/local/share/vegguide' if $class->IsProduction();
    return Cwd::abs_path(
        dirname( $INC{'VegGuide/Config.pm'} ) . '/../../share' );
}

sub EtcDir {
    my $class = shift;

    return '/etc/vegguide' if $class->IsProduction();
    return Cwd::abs_path(
        dirname( $INC{'VegGuide/Config.pm'} ) . '/../../etc' );
}

sub CacheDir {
    my $class = shift;

    return $class->IsProduction()
        ? '/var/cache/vegguide'
        : File::Spec->catdir( __PACKAGE__->_HomeDir(), '.vegguide', 'cache' );
}

sub _HomeDir {
    return ( getpwuid($>) )[7];
}

sub AlzaboRootDir {
    my $class = shift;

    return '/var/lib/alzabo' if $class->IsProduction();
    return Cwd::abs_path(
        File::Spec->catdir(
            dirname( $INC{'VegGuide/Config.pm'} ),
            '..',
            '..',
            'data',
            'alzabo',
        )
    );
}

{
    my %BaseConfig = (
        is_production        => __PACKAGE__->IsProduction(),
        using_frontend_proxy => ( $ENV{PLACK_ENV} ? 1 : 0 ),

        default_view => 'Mason',

        session => {
            expires          => ( 60 * 5 ),
            dbi_table        => 'Session',
            dbi_dbh          => 'VegGuide::Plugin::Session::Store::VegGuide',
            rewrite_body     => 0,
            rewrite_redirect => 1,
        },

        'Plugin::Cache' => {
            backend => {
                share_file => File::Spec->catfile(
                    __PACKAGE__->CacheDir(), 'cache.mmap'
                ),
                cache_size => '1m',
            },
        },

        authen_cookie => {
            name   => 'VegGuide-user',
            domain => ( __PACKAGE__->IsProduction() ? '.vegguide.org' : '' ),
            path   => '/',
            mac_secret => VegGuide::Config->MACSecret(),
        },

        dbi => { user => 'root' },

        'Log::Dispatch' => {
            class     => 'Screen',
            name      => 'Screen',
            min_level => ( __PACKAGE__->IsProduction() ? 'warn' : 'debug' ),
        },
    );

    $BaseConfig{root} = __PACKAGE__->ShareDir();

    unless ( __PACKAGE__->IsProduction() ) {
        $BaseConfig{'Plugin::Static::Simple'} = {
            dirs         => [qw( entry-images images js css api-explorer static w3c )],
            include_path => [
                __PACKAGE__->ShareDir(),
                __PACKAGE__->VarLibDir(),
            ],
            debug => 1,
        };
    }

    sub CatalystConfig {
        return %BaseConfig;
    }

    sub DBConnectParams {
        return %{ $BaseConfig{dbi} };
    }
}

sub MasonConfig {
    my $class = shift;

    my %config = (
        comp_root => File::Spec->catdir( $class->ShareDir(), 'mason' ),
        data_dir =>
            File::Spec->catdir( $class->CacheDir(), 'mason', 'web' ),
        error_mode => 'fatal',
        in_package => 'VegGuide::Mason',
        use_match  => 0,
    );

    if ( $class->IsProduction() ) {
        $config{static_source}            = 1;
        $config{static_source_touch_file} = $class->MasonTouchFile();
    }

    return %config;
}

sub MasonTouchFile {
    my $class = shift;

    return File::Spec->catfile( $class->EtcDir(), 'mason-touch' );
}

sub CanonicalWebHostname {
    my $class = shift;

    my $hostname = $class->Hostname();
    $hostname = 'www.vegguide.org' if $hostname eq 'vegguide.org';
    $hostname .= ':' . ( $ENV{SERVER_PORT} // 3000 )
        unless $class->IsProduction();

    return $hostname;
}

{
    my $Revision;

    sub StaticPrefix {
        my $class = shift;

        return unless $class->IsProduction();

        return $Revision ||= read_file(
            File::Spec->catfile( $class->EtcDir(), 'revision' ) );
    }
}

{
    my $Secret;

    sub ForgotPWSecret {
        my $class = shift;

        return $Secret if defined $Secret;

        $Secret
            = $class->IsProduction()
            ? read_file(
            File::Spec->catfile( $class->EtcDir(), 'forgot-pw-secret' ) )
            : 'a bigger secret';

        return $Secret;
    }
}

{
    my $Secret;

    sub MACSecret {
        my $class = shift;

        return $Secret if defined $Secret;

        return 'hack'
            if $VegGuide::Build::IsInstalling;

        $Secret
            = $class->IsProduction()
            ? read_file(
            File::Spec->catfile( $class->EtcDir(), 'mac-secret' ) )
            : 'a big secret';

        return $Secret;
    }
}

sub reCAPTCHAPublicKey {
    my $class = shift;

    return $class->IsProduction()
        ? '6LehbwAAAAAAAK0xSIX-jp96u7TVUwSJ9UmaOvIX'
        : '6LfcIwoAAAAAAKjgOYnMpaOgAPCO8_zbC2Ii7elS';
}

{
    my $Key;

    sub reCAPTCHAPrivateKey {
        my $class = shift;

        return $Key if defined $Key;

        $Key
            = $class->IsProduction()
            ? read_file(
            File::Spec->catfile( $class->EtcDir(), 'recaptcha-key' ) )
            : '6LfcIwoAAAAAAI5hcFFgP9Yn1-ijRqdnLIRAjFui ';

        return $Key;
    }
}

{
    my %GoogleKeys = (
        prod => {
            api => 'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQJbrWfLEAEyqTG'
                . 'EuLojCrBX82DARRenHsFYS69EyIksb1Zp6vMyATaFw',
        },
        test => {
            api => 'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQFhTS8R6luU5KHR'
                . '0NmLWmiFo6Z6RTyYdsJX2w7MzzF-Wh74HXvDfC94g'
        },
        houseabsolute => {
            api => 'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBT_1JRxtqVlOCGke'
                . 'WJdUu0IrTARLxSV7BZGDD_9EMRSI9hpiwTNN7SGnw',
            maps =>
                'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBSw9P60N-rQ5lcgR'
                . 'tnIXxrdsScYtBRPfFhhVza6LvWO1BLzbkJgflMmJw',
        },
        quasar => {
            api => 'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQFhFhoNZhGufL3u'
                . '1KMn-Gribk6CxQfkWDMlOmW4DDVW6rx39BPNlXXCg',
            maps => 'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQEo6hVy4-bEjn28'
                . 'puWiBmyTXGfmhQbdEayETtkVC4lkm8RGbQWyVvclg'
        },

        # XXX - this is probably wrong, since the API key needs to
        # be for the hostname without the port, but whatever (for
        # now).
        ubuntu => {
            api => 'ABQIAAAA3LiNPmeEprK9dgIE--1DFxSI9W9M0qPRGiQ9'
                . 'FSoMnIDXidyQDRTk0Uf6B-VrqIHeV-G8sQ0zUxI56g'
        },
    );

    for my $k ( keys %GoogleKeys ) {
        $GoogleKeys{$k}{maps} = $GoogleKeys{$k}{api}
            unless $GoogleKeys{$k}{maps};
    }

    sub GoogleAPIKey {
        my $class = shift;

        return $class->_GoogleKey('api');
    }

    sub GoogleMapsAPIKey {
        my $class    = shift;
        my $hostname = shift;

        return $class->_GoogleKey( 'maps', $hostname );
    }

    sub _GoogleKey {
        my $class    = shift;
        my $type     = shift;
        my $hostname = shift || VegGuide::Config->Hostname();

        my ($host) = $hostname =~ /^([^.]+)(?:\.|$)/;
        $host = 'prod'
            if !$GoogleKeys{$host} && VegGuide::Config->IsProduction();

        return $GoogleKeys{$host}{$type} || 'none';
    }
}

if ( __PACKAGE__->IsProduction() && $ENV{PLACK_ENV} ) {
    __PACKAGE__->$_() for qw( ForgotPWSecret MACSecret reCAPTCHAPrivateKey );
}

1;
