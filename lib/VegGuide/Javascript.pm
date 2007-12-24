package VegGuide::Javascript;

use strict;
use warnings;

use DateTime;
use File::Copy ();
use File::Path ();
use File::Spec;
use File::Temp ();
use JavaScript::Squish;
use JSAN::ServerSide 0.04;
use List::MoreUtils qw( all );
use Time::HiRes ();
use VegGuide::Config;


sub _Files
{
    my $dir = File::Spec->catdir( VegGuide::Config->ShareDir(), 'js-source' );

    my $js =
        JSAN::ServerSide->new( js_dir     => $dir,
                               # This is irrelevant, as we won't be
                               # servering the individual files.
                               uri_prefix => '/',
                             );

    $js->add('VegGuide');

    return $js->files();
}

{
    my $JSDir = File::Spec->catdir( VegGuide::Config->VarLibDir(), 'js' );
    File::Path::mkpath( $JSDir, 0, 0755 )
        unless -d $JSDir;

    my $CombinedFile = File::Spec->catfile( $JSDir, 'vegguide-combined.js' );

    my $Squish = JavaScript::Squish->new();

    my @Exceptions = ( qr/\@cc_on/,
                       qr/\@if/,
                       qr/\@end/,
                     );

    sub CreateSingleFile
    {
        my ( $fh, $tempfile ) = File::Temp::tempfile( UNLINK => 0 );

        my $now =
            DateTime->from_epoch
                ( epoch => Time::HiRes::time(),
                  time_zone => 'local' )
                    ->strftime( '%Y-%m-%d %H:%M:%S.%{nanosecond}' );

        print $fh "/* Generated at $now */\n\n";

        for my $file ( __PACKAGE__->_Files() )
        {
            print $fh "\n\n/* $file */\n\n";

            my $code = File::Slurp::read_file($file);
            $Squish->data($code);
            $Squish->remove_comments( exceptions => \@Exceptions );

            print $fh $Squish->data();
        }

        close $fh;

        File::Copy::move( $tempfile => $CombinedFile )
            or die "Cannot move $tempfile => $CombinedFile: $!";
    }

    sub CombinedFile { return $CombinedFile }
}
