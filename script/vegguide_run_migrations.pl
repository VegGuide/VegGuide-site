#!/usr/bin/perl

use strict;
use warnings;

use Cwd qw( abs_path );
use File::Basename qw( basename dirname );
use File::Slurp qw( read_file write_file );
use List::Util qw( max);


my $MigrationFile = '/etc/vegguide/migration-version';
my $Dir = abs_path( dirname($0) );


main();

sub main
{
    my $current = current_version();
    my $highest = highest_version();

    exit 0 if $current == $highest;

    for my $ver ( ( $current + 1 ) .. $highest )
    {
        run_scripts($ver);
    }

    record_version($highest);
}

sub current_version
{
    return 0 unless -f $MigrationFile;

    return read_file($MigrationFile);
}

sub highest_version
{
    my $highest = max( map { basename($_) } glob "$Dir/migrations/*" );

    return $highest || 0;
}

sub record_version
{
    my $version = shift;

    write_file( $MigrationFile, $version );
}

sub run_scripts
{
    my $ver = shift;

    print "Running migrations for version $ver\n";
    for my $script ( sort grep { -f && -x } glob "$Dir/migrations/$ver/*" )
    {
        print "  - ", basename($script), "\n";
        system( $script )
            and die "Cannot run $script: $!";
    }
}
