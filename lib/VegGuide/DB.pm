use utf8;
package VegGuide::DB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qtZwB9l/SF+S59YX60ACOw

use VegGuide::Config;

{
    my $Schema;

    sub Schema {
        my $class = shift;

        return $Schema ||= $class->connect( \&_dbh );
    }
}

sub _dbh {
    my %p = VegGuide::Config->DBConnectParams();

    my $dbh = DBI->connect(
        'dbi:mysql:database=RegVeg',
        $p{user},
        $p{password},
        {
            AutoCommit         => 1,
            RaiseError         => 1,
            ShowErrorStatement => 1,
        },
    );

    $dbh->{mysql_enable_utf8} = 1;

    return $dbh;
}

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
