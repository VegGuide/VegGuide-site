package VegGuide::Role::Tabs;

use strict;
use warnings;

use Scalar::Util qw( blessed );
use VegGuide::Web::Tab;
use Tie::IxHash;

use Moose::Role;

has _tabs => (
    is       => 'ro',
    isa      => 'Tie::IxHash',
    lazy     => 1,
    default  => sub { Tie::IxHash->new() },
    init_arg => undef,
    handles  => {
        tabs      => 'Values',
        _add_tab  => 'Push',
        tab_by_id => 'FETCH',
    },
);

sub add_tab {
    my $self = shift;
    my $tab  = shift;

    $tab = VegGuide::Web::Tab->new( %{$tab} )
        unless blessed $tab;

    $self->_add_tab( $tab->id() => $tab );
}

1;
