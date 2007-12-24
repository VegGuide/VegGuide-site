package VegGuide::Plugin::ResponseAttributes;

use strict;
use warnings;

use VegGuide::AlternateLinks;
use VegGuide::Breadcrumbs;
use VegGuide::Keywords;


sub prepare
{
    my $class = shift;

    my $c = $class->NEXT::prepare(@_);

    $c->response()->alternate_links( VegGuide::AlternateLinks->new() );
    $c->response()->breadcrumbs( VegGuide::Breadcrumbs->new($c) );
    $c->response()->keywords( VegGuide::Keywords->new() );

    return $c;
}


1;
