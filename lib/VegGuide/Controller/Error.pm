package VegGuide::Controller::Error;

use strict;
use warnings;
use namespace::autoclean;

use Moose;

BEGIN { extends 'VegGuide::Controller::DirectToView'; }

__PACKAGE__->meta()->make_immutable();

1;

