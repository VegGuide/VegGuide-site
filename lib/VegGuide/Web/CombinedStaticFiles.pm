package VegGuide::Web::CombinedStaticFiles;

use strict;
use warnings;

use autodie;
use DateTime;
use File::Copy qw( move );
use File::Slurp qw( read_file );
use File::Temp qw( tempfile );
use Path::Class;
use VegGuide::Util qw( string_is_empty );
use Time::HiRes;

use Moose;

has 'files' => (
    is      => 'ro',
    isa     => 'ArrayRef[Path::Class::File]',
    lazy    => 1,
    builder => '_files',
);

has 'target_file' => (
    is      => 'ro',
    isa     => 'Path::Class::File',
    lazy    => 1,
    builder => '_target_file',
);

has 'header' => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

sub create_single_file {
    my $self = shift;

    my ( $fh, $tempfile ) = tempfile( UNLINK => 0 );

    my $now = DateTime->from_epoch(
        epoch     => time,
        time_zone => 'local',
    )->strftime('%Y-%m-%d %H:%M:%S.%{nanosecond} %{time_zone_long_name}');

    print {$fh} "/* Generated at $now */\n\n";

    my $header = $self->header();
    print {$fh} $header
        unless string_is_empty($header);

    for my $file ( @{ $self->files() } ) {
        print {$fh} "\n\n/* $file */\n\n";
        print {$fh} $self->_squish( scalar read_file( $file->stringify() ) );
    }

    close $fh;

    my $target = $self->target_file();
    move( $tempfile => $target )
        or die "Cannot move $tempfile => $target: $!";
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
