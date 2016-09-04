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
        +VegGuide::Plugin::FixupURI
        +VegGuide::Plugin::ResponseAttributes
        +VegGuide::Plugin::Session::State::URI
        +VegGuide::Plugin::Session::Store::VegGuide
        +VegGuide::Plugin::User
        AuthenCookie
        Cache
        Cache::Store::FastMmap
        DR::Session
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
    my @Roles = qw(
        VegGuide::Role::Tabs
        VegGuide::Role::Engine::ErrorHandling
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
        using_frontend_proxy => 1,
        encoding             => 'UTF-8',
        default_view         => 'Mason',

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
    );

    if ( $class->IsProduction() ) {
        $config{static_source}            = 1;
        $config{static_source_touch_file} = $class->MasonTouchFile();
    }

    return (
        interp_args => \%config,
        globals     => [
            [ '$c', sub { $_[1] } ],
        ],
    );
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

sub GoogleAPIKey {
    my $class = shift;

    return q{} if $ENV{HARNESS_ACTIVE};

    my $key = read_file(
        File::Spec->catfile( $class->EtcDir(), 'google-api-key' ) );
    $key =~ s/^\s+|\s+$//g;

    return $key;
}

if ( __PACKAGE__->IsProduction() && $ENV{PLACK_ENV} ) {
    __PACKAGE__->$_()
        for qw( ForgotPWSecret GoogleAPIKey MACSecret reCAPTCHAPrivateKey );
}

1;
