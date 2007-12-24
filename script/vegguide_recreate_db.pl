#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";

use VegGuide::Config;
use VegGuide::Schema;


my %c = VegGuide::Config->DBConnectParams();
delete $c{dsn};

my $schema = VegGuide::Schema->CreateSchema();

$schema->drop(%c);
$schema->create(%c);

