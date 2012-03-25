package VegGuide::LocationComment;

use strict;
use warnings;

use parent 'VegGuide::Comment';

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema->LocationComment_t );

use VegGuide::Location;

sub location { VegGuide::Location->new( location_id => $_[0]->location_id ) }

1;
