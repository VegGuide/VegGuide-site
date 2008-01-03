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
    my $IsProd = $Hostname =~ /(?:vegguide|vegcrew|satyr)/ ? 1 : 0;
    my $IsTest = $Hostname =~ /test\.vegguide|test-install/;

    sub Hostname { return $Hostname }

    sub IsProduction { return $IsProd || $IsTest }

    sub IsTest { return $IsTest }
}

{
    my @StandardImports =
        qw( +VegGuide::Plugin::Authentication
            +VegGuide::Plugin::Authentication::Credential::DBMS
            +VegGuide::Plugin::Authentication::Store::DBMS
            +VegGuide::Plugin::ErrorHandling
            +VegGuide::Plugin::InOutEncoding
            +VegGuide::Plugin::Redirect
            +VegGuide::Plugin::ResponseAttributes
            +VegGuide::Plugin::Session
            +VegGuide::Plugin::Session::State::URI
            +VegGuide::Plugin::Session::Store::VegGuide
            Cache
            Cache::Store::FastMmap
            Log::Dispatch
            SubRequest
          );
    sub CatalystImports
    {
        my $class = shift;

        return @StandardImports
            if $class->IsProduction() || $class->Profiling();

        return ( @StandardImports,
                 qw( StackTrace
                     Static::Simple
                   )
               );
    }
}

{
    my @Profilers =
        qw( Devel/DProf.pm
            Devel/Profile.pm
            Devel/Profiler.pm
            Devel/SmallProf.pm
          );

    sub Profiling
    {
        return grep { $INC{$_} } @Profilers;
    }
}

sub VarLibDir
{
    my $class = shift;

    return $class->IsProduction()
           ? '/var/lib/vegguide'
           : File::Spec->catdir( __PACKAGE__->_HomeDir(), '.vegguide', 'var', 'lib' )
}

sub ShareDir
{
    my $class = shift;

    return $class->IsProduction() ? '/usr/local/share/vegguide' : Cwd::abs_path('share');
}

sub EtcDir
{
    my $class = shift;

    return $class->IsProduction() ? '/etc/vegguide' : Cwd::abs_path('etc');
}

sub CacheDir
{
    my $class = shift;

    return $class->IsProduction()
        ? '/var/cache/vegguide'
        : File::Spec->catdir( __PACKAGE__->_HomeDir(), '.vegguide', 'cache' );
}

sub _HomeDir
{
    return ( getpwuid($>) )[7];
}

sub AlzaboRootDir
{
    my $class = shift;

    return '/var/lib/alzabo' if $class->IsProduction();
    return
        Cwd::abs_path
            ( File::Spec->catdir
                  ( dirname( $INC{'VegGuide/Config.pm'} ),
                    '..',
                    '..',
                    'data',
                    'alzabo',
                  )
            );
}

{
    my %BaseConfig =
        ( is_production  => __PACKAGE__->IsProduction(),

          default_view   => 'Mason',

          session        =>
          { expires        => ( 60 * 5 ),
            dbi_table      => 'Session',
            dbi_dbh        => 'VegGuide::Plugin::Session::Store::VegGuide',
          },

          cache =>
          { backend =>
            { share_file =>
              File::Spec->catfile( __PACKAGE__->CacheDir(), 'cache.mmap' ),
              cache_size => '1m',
            },
          },

          authentication =>
          { default_realm => 'default',
            realms =>
            { default =>
              { store =>
                { class => '+VegGuide::Plugin::Authentication::Store::DBMS' },
                credential =>
                { class => '+VegGuide::Plugin::Authentication::Credential::DBMS' },
              },
            },
            use_session   => 0,
            cookie_name   => 'VegGuide-user',
            cookie_domain => ( __PACKAGE__->IsProduction() ? '.vegguide.org' : '' ),
          },

          dbi =>
          { user => 'root' },

          __PACKAGE__->_LogConfig(),
        );

    $BaseConfig{root} = __PACKAGE__->ShareDir();

    unless (  __PACKAGE__->IsProduction() )
    {
        $BaseConfig{static} = { dirs         => [ qw( images js css static w3c ) ],
                                include_path => [ __PACKAGE__->ShareDir(),
                                                  __PACKAGE__->VarLibDir() ],
                                debug => 1,
                              };
    }

    sub _LogConfig
    {
        my $class = shift;

        my @loggers;
        if ( $class->IsProduction() && $ENV{MOD_PERL} )
        {
            require Apache2::ServerUtil;

            push @loggers, { class     => 'ApacheLog',
                             name      => 'ApacheLog',
                             min_level => 'warning',
                             apache    => Apache2::ServerUtil->server(),
                             callbacks => sub { my %m = @_;
                                                return 'vegguide: ' . $m{message} },
                           };
        }
        else
        {
            push @loggers, { class     => 'Screen',
                             name      => 'Screen',
                             min_level => 'debug',
                           };
        }

        return ( 'Log::Dispatch' => \@loggers );
    }

    sub CatalystConfig
    {
        return %BaseConfig;
    }

    sub DBConnectParams
    {
        return %{ $BaseConfig{dbi} };
    }
}

sub MasonConfig
{
    my $class = shift;

    return
        ( comp_root  =>
          File::Spec->catdir( $class->ShareDir(), 'mason' ),
          data_dir   =>
          File::Spec->catdir( $class->CacheDir(), 'mason', 'web' ),
          error_mode => 'fatal',
          in_package => 'VegGuide::Mason',
          use_match  => 0,
        );
}

sub CanonicalWebHostname
{
    my $class = shift;

    my $hostname = $class->Hostname();
    $hostname = 'www.vegguide.org' if $hostname eq 'vegguide.org';
    $hostname .= ':3000'
        unless $class->IsProduction();

    return $hostname;
}

{
    my $Revision;
    sub StaticPrefix
    {
        my $class = shift;

        return unless $class->IsProduction();

        return $Revision ||= read_file( File::Spec->catfile( $class->EtcDir(), 'revision' ) );
    }
}

{
    my $Secret;
    sub ForgotPWSecret
    {
        my $class = shift;

        return $Secret if defined $Secret;

        $Secret =
            $class->IsProduction()
            ? read_file( File::Spec->catfile( $class->EtcDir(), 'forgot-pw-secret' ) )
            : 'a bigger secret';

        return $Secret;
    }
}

{
    my $Secret;
    sub MACSecret
    {
        my $class = shift;

        return $Secret if defined $Secret;

        $Secret =
            $class->IsProduction()
            ? read_file( File::Spec->catfile( $class->EtcDir(), 'mac-secret' ) )
            : 'a big secret';

        return $Secret;
    }
}

sub reCAPTCHAPublicKey
{
    my $class = shift;

    return
        $class->IsProduction()
        ? '6LehbwAAAAAAAK0xSIX-jp96u7TVUwSJ9UmaOvIX'
        : '6LefbwAAAAAAAKn5MAqAChKVasjtLYjywB9F8wSo';
}

{
    my $Key;
    sub reCAPTCHAPrivateKey
    {
        my $class = shift;

        return $Key if defined $Key;

        $Key =
            $class->IsProduction()
            ? read_file( File::Spec->catfile( $class->EtcDir(), 'recaptcha-key' ) )
            : '6LefbwAAAAAAAIZduCwvBWVy7JUcsD-TOAOreKeL';

        return $Key;
    }
}

{
    my %GoogleKeys =
        ( prod          => { api  =>
                             'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQJbrWfLEAEyqTG'
                             . 'EuLojCrBX82DARRenHsFYS69EyIksb1Zp6vMyATaFw',
                           },
          test          => { api  =>
                             'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQFhTS8R6luU5KHR'
                             . '0NmLWmiFo6Z6RTyYdsJX2w7MzzF-Wh74HXvDfC94g'
                           },
          houseabsolute => { api  =>
                             'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBT_1JRxtqVlOCGke'
                             . 'WJdUu0IrTARLxSV7BZGDD_9EMRSI9hpiwTNN7SGnw',
                             maps =>
                             'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBSw9P60N-rQ5lcgR'
                             . 'tnIXxrdsScYtBRPfFhhVza6LvWO1BLzbkJgflMmJw',
                           },
          quasar        => { api =>
                             'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQFhFhoNZhGufL3u'
                             . '1KMn-Gribk6CxQfkWDMlOmW4DDVW6rx39BPNlXXCg',
                             maps =>
                             'ABQIAAAAjHnXmSTxRbss2TGS1AOjhBQEo6hVy4-bEjn28'
                             . 'puWiBmyTXGfmhQbdEayETtkVC4lkm8RGbQWyVvclg'
                           },
          # XXX - this is probably wrong, since the API key needs to
          # be for the hostname without the port, but whatever (for
          # now).
	  ubuntu	=> { api =>
                             'ABQIAAAA3LiNPmeEprK9dgIE--1DFxSI9W9M0qPRGiQ9'
                             . 'FSoMnIDXidyQDRTk0Uf6B-VrqIHeV-G8sQ0zUxI56g'
			   },
        );

    for my $k ( keys %GoogleKeys )
    {
        $GoogleKeys{$k}{maps} = $GoogleKeys{$k}{api}
            unless $GoogleKeys{$k}{maps};
    }

    sub GoogleAPIKey
    {
        my $class = shift;

        return $class->_GoogleKey('api');
    }

    sub GoogleMapsAPIKey
    {
        my $class = shift;

        return $class->_GoogleKey('maps');
    }

    sub _GoogleKey
    {
        my $class = shift;
        my $type  = shift;

        my $key =
              hostname() =~ /test/          ? 'test'
            : hostname() =~ /houseabsolute/ ? 'houseabsolute'
            : hostname() =~ /quasar/        ? 'quasar'
	    : hostname() =~ /ubuntu/        ? 'ubuntu'
            : $class->IsProduction()        ? 'prod'
            :                                 '';

        return $GoogleKeys{$key}{$type} || 'none';
    }
}

if ( __PACKAGE__->IsProduction() && $ENV{MOD_PERL} )
{
    __PACKAGE__->$_()
        for qw( ForgotPWSecret MACSecret reCAPTCHAPrivateKey );
}


1;
