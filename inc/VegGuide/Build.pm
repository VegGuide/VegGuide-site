package VegGuide::Build;

use strict;
use warnings;

use base 'Module::Build';

use File::Basename qw( basename dirname );
use File::Find::Rule;
use File::Path qw( mkpath );
use File::Spec;

$VegGuide::Build::IsInstalling = 1;


my %Requires =
    ( 'Alzabo'                                   => '0.92',
      'Captcha::reCAPTCHA'                       => '0',
      'Catalyst'                                 => '5.80007',
      'Catalyst::Action::REST'                   => '0.5',
      'Catalyst::Devel'                          => '0',
      'Catalyst::DR'                             => '0',
      'Catalyst::Engine::Apache2::MP20'          => '0',
      'Catalyst::Plugin::AuthenCookie'           => '0.01',
      'Catalyst::Plugin::Cache::Store::FastMmap' => '0',
      'Catalyst::Plugin::Log::Dispatch'          => '0.11',
      'Catalyst::Plugin::RedirectAndDetach'      => '0',
      'Catalyst::Plugin::Session'                => '0.17',
      'Catalyst::Plugin::Session::State'         => '0',
      'Catalyst::Plugin::Session::State::URI'    => '0.10',
      'Catalyst::Plugin::Session::Store'         => '0',
      'Catalyst::Plugin::Session::Store::DBI'    => '0',
      'Catalyst::Plugin::StackTrace'             => '0',
      'Catalyst::Plugin::Static::Simple'         => '0',
      'Catalyst::Plugin::SubRequest'             => '0',
      'Catalyst::Request::REST::ForBrowsers'     => '0',
      'Catalyst::View::Mason'                    => '0.13',
      'Chart::OFC'                               => '0.07',
      'Class::AlzaboWrapper'                     => '0.14',
      'Class::Trait'                             => '0.22',
      'Data::Dump::Streamer'                     => '0',
      'Data::Pageset'                            => '0',
      'DateTime'                                 => '0',
      'DateTime::Format::HTTP'                   => '0',
      'DateTime::Format::MySQL'                  => '0',
      'DateTime::Format::Strptime'               => '0',
      'DateTime::Format::W3CDTF'                 => '0',
      'DateTime::Locale'                         => '0.3',
      'DateTime::TimeZone'                       => '0.66',
      'Digest::SHA1'                             => '0',
      'Email::Address'                           => '1.886',
      'Email::Date'                              => '1.101',
      'Email::MessageID'                         => '1.35',
      'Email::Send'                              => '2.185',
      'Email::MIME::CreateHTML'                  => '0',
      'Email::Valid'                             => '0',
      'Encode'                                   => '2.23',
      'Exception::Class'                         => '1.24',
      'File::chdir'                              => '0',
      'File::Find::Rule'                         => '0',
      'File::LibMagic'                           => '0',
      'File::Slurp'                              => '0',
      'File::Tail'                               => '0',
      'Geo::Coder::Google'                       => '0.06',
      'Geo::IP'                                  => '0',
      'Geography::States'                        => '0',
      'HTML::Entities'                           => '0',
      'HTML::FillInForm'                         => '1.07',
      'Image::Magick'                            => '0',
      'Image::Size'                              => '0',
      'JavaScript::Squish'                       => '0',
      'JSAN::ServerSide'                         => '0.04',
      'JSON::XS'                                 => '0',
      'Lingua::EN::Inflect'                      => '0',
      'List::AllUtils'                           => '0',
      'LockFile::Simple'                         => '0',
      'LWPx::ParanoidAgent'                      => '0',
      'LWP::Simple'                              => '0',
      'Math::Round'                              => '0',
      'Net::OpenID::Consumer'                    => '0',
      'Params::Validate'                         => '0',
      'Sys::Hostname'                            => '0',
      'Text::WikiFormat'                         => '0',
      'Text::Wrap'                               => '0',
      'Tie::IxHash'                              => '0',
      'Time::HiRes'                              => '0',
      'URI::Escape'                              => '0',
      'URI::FromHash'                            => '0',
      'WebService::StreetMapLink'                => '0.21',
      'XML::Atom'                                => '0',
      'XML::Feed'                                => '0.41',
      'XML::Generator::RSS10'                    => '0',
      'XML::RSS'                                 => '0',
      'XML::SAX::Writer'                         => '0',
      'XML::Simple'                              => '0',
    );

sub new
{
    my $class = shift;

    return $class->SUPER::new
	( license            => 'perl',
	  module_name        => 'VegGuide',
	  requires           => \%Requires,
	  script_files       => [ glob('bin/*') ],
	  test_files         => [ glob('t/*.t'), glob('t/*/*.t') ]
	);
}

sub ACTION_modules
{
    delete $Requires{'Image::Magick'};

    print join ' ', sort keys %Requires;
    print "\n";
}

sub ACTION_install
{
    my $self = shift;

    $self->SUPER::ACTION_install(@_);

    $self->_install_extra();
}

sub _install_extra
{
    my $self = shift;

    $self->dispatch('make_etc_dir');
    $self->dispatch('copy_share_files');
    $self->dispatch('copy_system_files');
    $self->dispatch('make_entry_images_dir');
    $self->dispatch('make_user_images_dir');
    $self->dispatch('make_skin_images_dir');
    $self->dispatch('write_revision_file');
    $self->dispatch('make_cache_dir');
    $self->dispatch('generate_combined_js');
    $self->dispatch('copy_alzabo_schema');
    $self->dispatch('sync_db');
    $self->dispatch('generate_secrets');
    $self->dispatch('run_migrations');
    $self->dispatch('manual_reminder');
}

our $FAKE = 0;
sub ACTION_fakeinstall
{
    my $self = shift;

    $self->SUPER::ACTION_fakeinstall(@_);

    local $FAKE = 1;
    $self->_install_extra();
}

sub ACTION_copy_share_files
{
    my $self = shift;

    my @files = $self->_find_things('share');

    require VegGuide::Config;
    my $target_dir = VegGuide::Config->ShareDir();

    foreach my $file ( sort @files )
    {
        my $dir = dirname($file);
        $dir =~ s{^.*?share/?}{};

        my $to =
            File::Spec->catfile( $target_dir,
                                 $dir,
                                 basename($file) );

	if ($FAKE)
	{
	    $self->log_info("Copying $file -> $to\n");
	    next;
	}

        $self->copy_if_modified( from => $file,
                                 to   => $to,
                                 flatten => 1,
                               );
    }

    my $touch_file = VegGuide::Config->MasonTouchFile();
    open my $fh, '>', $touch_file
        or die "Cannot write to $touch_file: $!";
    print $fh time
        or die "Cannot write to $touch_file: $!";
    close $fh
        or die "Cannot close $touch_file: $!";
}

sub ACTION_copy_system_files
{
    my $self = shift;

    my @files = $self->_find_things( 'system', 'include dirs' );

    require VegGuide::Config;

    foreach my $file ( sort @files )
    {
	next if $file eq 'system';

	if ( -d $file )
	{
	    ( my $dir = $file ) =~ s{^.*?system}{};

	    next if -d $dir;

	    if ($FAKE)
	    {
		$self->log_info( "mkpath $dir" );
	    }
	    else
	    {
		mkpath( $dir, 1, 0755 )
	    }

	    next;
	}

        my $dir = dirname($file);
        $dir =~ s{^.*?system}{};

        my $to =
            File::Spec->catfile( $dir,
                                 basename($file) );

	if ($FAKE)
	{
	    $self->log_info("Copying $file -> $to\n");
	    next;
	}

        $self->copy_if_modified( from => $file,
                                 to   => $to,
                                 flatten => 1,
                               );

        if ( -f $file && -x _ )
        {
            chmod 0554, $to
                or die "Cannot chmod 0554 $file: $!";
        }
    }

    for my $file ( File::Find::Rule->new()->file()->in( '/etc/apache2/mods-available' ) )
    {
	my $to = File::Spec->catfile( '/etc/apache2-backend/mods-available',
				      basename($file) );

	if ($FAKE)
	{
	    $self->log_info("Copying $file -> $to\n");
	    next;
	}

        $self->copy_if_modified( from => $file,
                                 to   => $to,
                                 flatten => 1,
                               );
    }

    my $dir = '/var/log/apache2-backend';
    chmod 0750, $dir
	or die "Cannot chmod 0640 $dir: $!";

    my $adm_gid = getgrnam('adm');
    chown 0, $adm_gid, $dir
	or die "Cannot chown 0:$adm_gid $dir: $!";
}

sub _find_things
{
    my $self         = shift;
    my $dir          = shift;
    my $include_dirs = shift;

    my $rule = File::Find::Rule->new();

    $rule = $rule->or( $rule->new()
		       ->directory()
		       ->name('.hg')
		       ->prune()
		       ->discard(),

		       $rule->new()
		       ->name('*~')
		       ->prune()
		       ->discard(),

		       $rule->new()
		       ->name('#*#')
		       ->prune()
		       ->discard(),

		       $rule->new(),
		     );

    $rule->file()
	unless $include_dirs;

    return $rule->in($dir);
}

sub ACTION_make_entry_images_dir
{
    my $self = shift;

    return if $FAKE;

    require VegGuide::Config;
    my $target_dir = File::Spec->catdir( VegGuide::Config->VarLibDir(), 'entry-images', );

    mkpath( $target_dir, 1, 0755 );

    my ( $uid, $gid ) = $self->_server_uid_gid();

    chown $uid, $gid, $target_dir
        or die "Cannot chown $uid:$gid $target_dir: $!";
}

sub ACTION_make_user_images_dir
{
    my $self = shift;

    return if $FAKE;

    require VegGuide::Config;
    my $target_dir = File::Spec->catdir( VegGuide::Config->VarLibDir(), 'user-images', );

    mkpath( $target_dir, 1, 0755 );

    my ( $uid, $gid ) = $self->_server_uid_gid();

    chown $uid, $gid, $target_dir
        or die "Cannot chown $uid:$gid $target_dir: $!";
}

sub ACTION_make_skin_images_dir
{
    my $self = shift;

    return if $FAKE;

    require VegGuide::Config;
    my $target_dir = File::Spec->catdir( VegGuide::Config->VarLibDir(), 'skin-images', );

    mkpath( $target_dir, 1, 0755 );

    my ( $uid, $gid ) = $self->_server_uid_gid();

    chown $uid, $gid, $target_dir
        or die "Cannot chown $uid:$gid $target_dir: $!";
}

sub _server_uid_gid
{
    my $uid = getpwnam('www-data');
    my $gid = getgrnam('www-data');

    return ( $uid, $gid );
}

sub ACTION_make_etc_dir
{
    my $self = shift;

    return if $FAKE;

    require VegGuide::Config;

    mkpath( VegGuide::Config->EtcDir(), 1, 0755 );
}

sub ACTION_write_revision_file
{
    my $self = shift;

    return if $FAKE;

    require VegGuide::Config;

    my ($revision) = `hg tip` =~ /changeset:\s+(\d+)/;

    return unless $revision;

    my $file = File::Spec->catdir( VegGuide::Config->EtcDir(), 'revision' );

    open my $fh, '>', $file
        or die "Cannot write to $file: $!";
    print $fh $revision
        or die "Cannot write to $file: $!";
    close $fh;
}

sub ACTION_make_cache_dir
{
    my $self = shift;

    return if $FAKE;

    require VegGuide::Config;

    my $rss_cache_dir = File::Spec->catdir( VegGuide::Config->CacheDir(), 'rss' );

    mkpath( $rss_cache_dir, 1, 0755 );

    my ( $uid, $gid ) = $self->_server_uid_gid();

    chown $uid, $gid, $rss_cache_dir
        or die "Cannot chown $uid:$gid $rss_cache_dir: $!";
}

sub ACTION_generate_combined_js
{
    my $self = shift;

    require VegGuide::Config;
    my $target_dir = VegGuide::Config->VarLibDir();

    mkpath( $target_dir, 1, 0755 )
        unless $FAKE;

    $self->log_info("Generating combined JS source file\n");

    return if $FAKE;

    require VegGuide::Javascript;
    VegGuide::Javascript->CreateSingleFile();

    my $file = VegGuide::Javascript->CombinedFile();
    chmod 0644, $file
        or die "Cannot chmod 0644 $file: $!";
}

sub ACTION_copy_alzabo_schema
{
    my $self = shift;

    require Alzabo::Config;

    my $schema_repo_dir =
        File::Spec->catdir( $self->base_dir(), qw( data alzabo schemas RegVeg ) );

    my $to_dir = File::Spec->catdir( Alzabo::Config::schema_dir(), 'RegVeg' );

    foreach my $file ( glob File::Spec->catfile( $schema_repo_dir, 'RegVeg.*' ) )
    {
	if ($FAKE)
	{
	    $self->log_info("Copying $file -> $to_dir\n");
	    next;
	}

        $self->copy_if_modified( from    => $file,
                                 to_dir  => $to_dir,
                                 flatten => 1,
			       );
    }
}

sub ACTION_sync_db
{
    my $self = shift;

    return if $FAKE;

    $self->do_system( './script/vegguide_sync_db.pl', '--data' );
}

sub ACTION_generate_secrets
{
    my $self = shift;

    require VegGuide::Config;

    my $target_dir = VegGuide::Config->EtcDir();

    mkpath( $target_dir, 1, 0755 )
        unless $FAKE;

    foreach my $f ( map { File::Spec->catfile( $target_dir, $_ ) }
                    qw( mac-secret forgot-pw-secret ) )
    {
        next if -e $f;

	$self->log_info("Writing secret to $f\n");

        next if $FAKE;

        open my $fh, '>', $f
            or die "Cannot write to $f: $!";

        print $fh $self->_generate_mac_secret()
            or die "Cannot write to $f: $!";

        close $fh;

        chmod 0640, $f
            or die "Cannot chmod 0640 $f: $!";
    }
}

sub _generate_mac_secret
{
    my @chars = ( 'a'..'z', 'A'..'Z', 0..9 );

    my $secret = '';
    $secret .= $chars[ rand @chars ] for 1..12;

    return $secret;
}

sub ACTION_run_migrations
{
    my $self = shift;

    return if $FAKE;

    mkpath( '/etc/vegguide', 1, 0755 )
        unless $FAKE;

    $self->do_system( qw( script/vegguide_run_migrations.pl ) );
}

sub ACTION_manual_reminder
{
    my $self = shift;

    require VegGuide::Config;
    my $etc_dir = VegGuide::Config->EtcDir();

    my $file = File::Spec->catfile( $etc_dir, 'recaptcha-key' );
    print "\n*** Don't forget to create $file\n\n"
        unless -f $file;
}

sub ACTION_find_unused_files
{
    my $self = shift;

    my %distro_share = $self->_file_map('share');

    require VegGuide::Config;

    my %system_share = $self->_file_map( VegGuide::Config->ShareDir() );

    $self->_print_non_matching( \%distro_share, \%system_share );

    my %distro_pm = $self->_file_map('lib/VegGuide');

    my $system_lib = File::Spec->catdir( $self->install_destination('lib'), 'VegGuide' );
    my %system_pm = $self->_file_map($system_lib);

    $self->_print_non_matching( \%distro_pm, \%system_pm );
}

sub _file_map
{
    my $self = shift;
    my $dir  = shift;

    my %map;
    for my $file ( $self->_find_things($dir) )
    {
        ( my $trimmed = $file ) =~ s{^\Q$dir\E/}{};;

        $map{$trimmed} = $file;
    }

    return %map;
}

sub _print_non_matching
{
    my $self   = shift;
    my $distro = shift;
    my $system = shift;

    for my $file ( sort keys %{ $system } )
    {
        print $system->{$file}, "\n"
            unless $distro->{$file};
    }
}


1;
