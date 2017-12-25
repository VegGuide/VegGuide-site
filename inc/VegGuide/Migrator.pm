package VegGuide::Migrator;

use strict;
use warnings;

use Database::Migrator::Types qw( Dir );
use Path::Class qw( dir file );
use Moose;

extends 'Database::Migrator::mysql';

has '+database' => (
    required => 0,
    default  => 'RegVeg',
);

has '+password' => (
    default => sub {
        return unless -f '/etc/vegguide/mysql-password';
        my $pw = file('/etc/vegguide/mysql-password')->slurp;
        chomp $pw;
        return $pw;
    }
);

has '+migration_table' => (
    init_arg => undef,
    required => 0,
    default  => 'AppliedMigration',
);

has '+migrations_dir' => (
    init_arg => undef,
    required => 0,
    builder  => '_build_migrations_dir',
);

has '+schema_file' => (
    init_arg => undef,
    required => 0,
    builder  => '_build_schema_file',
);

has _schema_dir => (
    is       => 'ro',
    isa      => Dir,
    init_arg => undef,
    builder  => '_build_schema_dir',
);

sub _build_migrations_dir {
    my $self = shift;

    return $self->_schema_dir()->subdir('migrations');
}

sub _build_schema_file {
    my $self = shift;

    return $self->_schema_dir()->file('RegVeg.sql');
}

sub _build_schema_dir {
    my $self = shift;

    my $pm_file = __PACKAGE__ =~ s{::}{/}r;
    $pm_file .= '.pm';

    return dir( $INC{$pm_file} )->parent()->parent()->parent()
        ->subdir('schema');
}

1;
