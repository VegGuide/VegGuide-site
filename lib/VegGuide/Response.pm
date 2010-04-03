package VegGuide::Response;

use strict;
use warnings;

use base 'Catalyst::Response';
__PACKAGE__->mk_accessors( 'alternate_links', 'breadcrumbs', 'keywords' );

1;
