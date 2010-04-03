package VegGuide::Search;

use strict;
use warnings;

use URI::FromHash qw( uri );
use VegGuide::Exceptions qw( virtual_method_error );
use VegGuide::Validate qw( validate SCALAR_TYPE );

sub new {
    my $class = shift;
    my %p = validate( @_, { $class->SearchParams() } );

    return bless \%p, $class;
}

sub clone {
    my $self = shift;

    my %new = %{$self};

    return bless \%new, ref $self;
}

sub cursor_params {
    my $self = shift;

    return %{ $self->{cursor_params} || {} };
}

sub order_by {
    $_[0]->{cursor_params}{order_by} || $_[0]->_default_order_by();
}

sub sort_order {
    $_[0]->{cursor_params}{sort_order}
        || $_[0]->_default_sort_order( $_[0]->order_by() );
}
sub page  { $_[0]->{cursor_params}{page} }
sub limit { $_[0]->{cursor_params}{limit} }

sub _default_order_by {'name'}

sub _default_sort_order {
    my $self     = shift;
    my $order_by = shift;

    return $order_by eq 'created' ? 'DESC' : 'ASC';
}

sub opposite_sort_order { $_[0]->sort_order() eq 'ASC' ? 'DESC' : 'ASC' }

sub pager {
    my $self = shift;

    return VegGuide::Pageset->new(
        {
            total_entries    => $self->count(),
            entries_per_page => $self->limit(),
            current_page     => $self->page(),
            pages_per_set    => 10,
        },
    );
}

sub count   { virtual_method_error( $_[0] ) }
sub _cursor { virtual_method_error( $_[0] ) }

sub ColumnNameToOrderBy {
    my $self = shift;
    my $name = shift;

    return 'created' if $name eq 'Created On';

    return 'modified' if $name eq 'Last Updated On';

    $name =~ s/^\s+|\s+$//g;
    $name =~ s/ /_/g;

    $name =~ s/[^\w_]//g;

    return lc $name;
}

1;
