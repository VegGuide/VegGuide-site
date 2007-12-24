package VegGuide::Controller::Stats;

use strict;
use warnings;

use base 'VegGuide::Controller::DirectToView';

use VegGuide::Chart;


sub _breadcrumb_title
{
    return 'Site Stats';
}

sub chart_data : Local
{
    my $self = shift;
    my $c    = shift;

    $c->response->content_type('text/plain');
    $c->response->status(200);

    $c->response->body( VegGuide::Chart->GrowthOverTime()->as_ofc_data() );

}


1;

