package VegGuide::Controller::Review;

use strict;
use warnings;
use namespace::autoclean;

use Scalar::Util qw( looks_like_number );
use VegGuide::Search::Review;

use Moose;

BEGIN { extends 'VegGuide::Controller::Base'; }

sub list : Path('') {
    my $self = shift;
    my $c    = shift;

    my $search = VegGuide::Search::Review->new();

    my $params = $c->request()->parameters();
    my %p
        = map { $_ => $params->{$_} }
        grep { defined $params->{$_} } qw( order_by sort_order page limit );

    my $limit = $params->{limit} || $c->vg_user()->entries_per_page();

    $limit = 20 unless looks_like_number($limit);
    $limit = 100 if $limit > 100;

    $p{limit} = $limit;

    $search->set_cursor_params(%p);

    $c->stash()->{search} = $search;
    $c->stash()->{pager}  = $search->pager();

    $c->stash()->{template} = '/site/review-list';
}

__PACKAGE__->meta()->make_immutable();

1;

