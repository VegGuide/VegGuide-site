package VegGuide::Controller::Review;

use strict;
use warnings;

use base 'VegGuide::Controller::Base';

use VegGuide::Search::Review;


sub list : Path('')
{
    my $self = shift;
    my $c    = shift;

    my $search = VegGuide::Search::Review->new();

    my $params = $c->request()->parameters();
    my %p =
      map { $_ => $params->{$_} }
      grep { defined $params->{$_} }
      qw( order_by sort_order page limit );

    $search->set_cursor_params(%p);

    $c->stash()->{search} = $search;
    $c->stash()->{pager } = $search->pager();

    $c->stash()->{template} = '/site/review-list';
}

1;

