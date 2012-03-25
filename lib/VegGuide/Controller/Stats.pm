package VegGuide::Controller::Stats;

use strict;
use warnings;

use parent 'VegGuide::Controller::DirectToView';

use VegGuide::Chart;

sub _add_tabs {
    my $self = shift;
    my $c    = shift;

    $c->add_tab($_)
        for (
        {
            uri     => '/stats/site',
            label   => 'Site stats',
            tooltip => 'General stats for the whole site',
            id      => 'site',
        }, {
            uri     => '/stats/top20',
            label   => 'Top 20 Lists',
            tooltip => 'Top 20 people and entries',
            id      => 'top20',
        }, {
            uri     => '/stats/charts',
            label   => 'Charts',
            tooltip => 'Fancy charts',
            id      => 'charts',
        },
        );

    my ($page) = ( split /\//, $c->request()->uri() )[-1];

    my $tab = $c->tab_by_id($page);
    $tab->set_is_selected(1) if $tab;

    return 1;
}

sub _breadcrumb_title {
    return 'Site Stats';
}

sub chart_data : Local {
    my $self = shift;
    my $c    = shift;

    $c->response->content_type('text/plain');
    $c->response->status(200);

    $c->response->body( VegGuide::Chart->GrowthOverTime()->as_ofc_data() );

}

1;

