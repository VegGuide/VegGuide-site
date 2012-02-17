use strict;
use warnings;

use VegGuide;

my $app = VegGuide->apply_default_middlewares(VegGuide->psgi_app);
$app;

