package VegGuide::DB::ResultSet::NewsItem;

use strict;
use warnings;

use parent 'VegGuide::DB::ResultSet';

sub most_recent {
    my $self = shift;

    my $cutoff = DateTime->today()->subtract( days => 14 );

    return $self->search(
        { 'creation_datetime' => { '>=', $cutoff } },
        { rows                => 1 },
    )->single();
}

1;
