package VegGuide::Schema;

use strict;
use warnings;

use Alzabo::Runtime::Schema;
use File::Slurp         ();
use Lingua::EN::Inflect ();
use VegGuide::Config;

# Turns FooBar into foo_bar
sub calm_form {
    my $string = shift;

    $string =~ s/(^|.)([A-Z])/$1 ? "$1\L_$2" : "\L$2"/ge;

    return $string;
}

sub is_linking_table {
    my $t = shift;

    return (   $t->columns == 2
            && $t->primary_key_size == 2
            && ( my @temp = $t->all_foreign_keys ) == 2 );
}

sub _namer {
    my %p = @_;

    if ( $p{table} || $p{column} ) {
        my $table = $p{table} || $p{column}->table();

        return if $table->name() eq 'Session';

        unless ( grep { $p{type} eq $_ } qw( table table_column ) ) {
            return if is_linking_table($table);
        }
    }

    if ( $p{type} eq 'table' ) {
        my $name = $p{table}->name() . '_t';

        return if defined &{"VegGuide::Alzabo::Schema::$name"};

        return $name;
    }

    if ( $p{type} eq 'table_column' ) {
        my $table = $p{column}->table()->name();
        my $name  = $p{column}->name() . '_c';

        return if defined &{"VegGuide::Alzabo::Table::${table}::$name"};

        return $name;
    }

    if ( $p{type} eq 'foreign_key' ) {
        my $name = $p{foreign_key}->table_to->name;
        my $from = $p{foreign_key}->table_from->name;
        $name =~ s/$from//;

        my $method;
        if ( $p{plural} ) {
            $method = my_PL( calm_form($name) );
        }
        else {
            $method = calm_form($name);
        }

        $method =~ s/date_time/datetime/;

        return if defined &{"VegGuide::Alzabo::Row::${from}::$method"};

        return $method;
    }

    if ( $p{type} eq 'linking_table' ) {
        my $method = $p{foreign_key}->table_to->name;
        my $tname  = $p{foreign_key}->table_from->name;
        $method =~ s/$tname//;

        my $name = my_PL( calm_form($method) );

        return if defined &{"VegGuide::Alzabo::Row::${tname}::$name"};

        return $name;
    }

    die "unknown type in call to naming sub: $p{type}\n";
}

sub my_PL {
    my $name = shift;

    return 'hours' if $name eq 'hours';

    return Lingua::EN::Inflect::PL($name);
}

BEGIN {
    Alzabo::Config::root_dir( VegGuide::Config->AlzaboRootDir() );
}

# needs to come after above sub definitions
use Alzabo::MethodMaker (
    schema         => 'RegVeg',
    class_root     => 'VegGuide::Alzabo',
    name_maker     => \&_namer,
    tables         => 1,
    table_columns  => 1,
    foreign_keys   => 1,
    linking_tables => 1,
);

{
    my $Schema;
    my $LastPid;

    sub Connect {
        my $class = shift;

        # If we get a schema during server startup, but we want to
        # reconnect in Apache child processes.
        if ( $Schema && $Schema->driver()->handle() ) {
            unless ( $LastPid == $$ ) {
                $Schema->disconnect();
                $Schema->connect();

                $LastPid = $$;

                return $Schema;
            }
        }

        if ( $Schema && $Schema->driver()->handle() ) {
            unless ( $Schema->driver()->handle()->ping() ) {
                $Schema->disconnect();
                $Schema->connect();
            }

            return $Schema;
        }

        my $schema = $class->Schema();

        my %c = VegGuide::Config->DBConnectParams();

        $schema->set_user( $c{user} );
        $schema->set_password( $c{password} ) if $c{password};

        $schema->connect();

        $schema->driver()->handle()->do(q{SET sql_mode = ''});

        $schema->VendorComment_t()
            ->set_prefetch( $schema->VendorComment_t()->columns() );
        $schema->LocationComment_t()
            ->set_prefetch( $schema->LocationComment_t()->columns() );

        $schema->set_referential_integrity(1);

        $LastPid = $$;

        return $schema;
    }

    sub Schema {
        return $Schema
            ||= Alzabo::Runtime::Schema->load_from_file( name => 'RegVeg' );
    }
}

sub CreateSchema {
    my $class = shift;

    require Alzabo::Create::Schema;
    return Alzabo::Create::Schema->load_from_file( name => 'RegVeg' );
}

sub ColumnNameAsLabel {
    shift;
    my $name = shift;

    $name =~ s/_/ /g;
    $name =~ s/(\d)$/ $1/;

    return ucfirst $name;
}

1;

__END__
