package VegGuide::Search::Review;

use strict;
use warnings;

use base 'VegGuide::Search';

use VegGuide::SiteURI qw( site_uri );
use VegGuide::VendorComment;
use VegGuide::Validate
    qw( validate SCALAR_TYPE );


sub SearchParams { () }

sub SearchKeys { () }

{
    my $spec = { order_by   => SCALAR_TYPE( default => undef ),
                 sort_order => SCALAR_TYPE( default => undef ),
                 page       => SCALAR_TYPE( default => 1 ),
                 limit      => SCALAR_TYPE( default => 20 ),
               };
    sub set_cursor_params
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        $p{order_by} ||= $self->_default_order_by();
        $p{sort_order} ||= $self->_default_sort_order( $p{order_by} );

        $self->{cursor_params} = \%p;
    }
}

sub _default_order_by
{
    return 'modified';
}

sub count
{
    return VegGuide::VendorComment->Count();
}

sub reviews
{
    my $self = shift;

    my %p = $self->cursor_params();

    my $page = delete $p{page} || 1;
    $p{start} = ( $page - 1 ) * ( $p{limit} || 20 );

    return $self->_cursor(%p);
}

sub _cursor
{
    my $self = shift;

    return VegGuide::VendorComment->All(@_);
}

sub title
{
    my $self = shift;

    return 'All reviews';
}

sub uri
{
    my $self = shift;
    my $page = shift || $self->page();

    return
        site_uri
            ( $self->_uri_base_params(),
              query    => { page       => $page,
                            limit      => $self->limit(),
                            order_by   => $self->order_by(),
                            sort_order => $self->sort_order(),
                          },
            );
}

sub base_uri
{
    my $self = shift;

    return site_uri( $self->_uri_base_params(@_) );
}

sub _uri_base_params
{
    my $self   = shift;

    return ( path => '/review/',
           );
}

{
    my %DefaultOrder = ( 'modified' => 'DESC',
                       );
    sub DefaultSortOrder
    {
        my $class = shift;
        my $order_by = shift;

        die "Invalid order by ($order_by)"
            unless $DefaultOrder{$order_by};

        return $DefaultOrder{$order_by};
    }
}

1;
