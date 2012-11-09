package VegGuide::DB::ResultSet;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

use VegGuide::Pageset;

sub pager {
    my $self  = shift;
    my $total = shift;

    my $pager = $self->SUPER::pager(@_);

    return VegGuide::Pageset->new(
        {
            total_entries => $total || $pager->total_entries(),
            entries_per_page => $pager->entries_per_page,
            current_page     => $pager->current_page,
            pages_per_set    => 1,
        }
    );
}

1;
