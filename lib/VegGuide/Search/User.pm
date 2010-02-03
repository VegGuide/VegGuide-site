package VegGuide::Search::User;

use strict;
use warnings;

use base 'VegGuide::Search';

use URI::FromHash ();
use VegGuide::User;
use VegGuide::Validate
    qw( validate SCALAR_TYPE SCALAR_OR_ARRAYREF_TYPE ARRAYREF_TYPE BOOLEAN_TYPE );


{
    # This is an array to preserve the order of the key names, so they
    # match the order in the filtering UI.
    my @SearchParams =
        ( real_name     => SCALAR_TYPE( default => undef ),
          email_address => SCALAR_TYPE( default => undef ),
        );

    my @SearchKeys   = grep { ! ref } @SearchParams;
    my $SearchParams = { @SearchParams };

    sub SearchParams { return @SearchParams }

    sub SearchKeys { return @SearchKeys }
}

for my $key ( __PACKAGE__->SearchKeys() )
{
    my $sub = sub { return unless defined $_[0]->{$key};
                    return $_[0]->{$key}; };

    no strict 'refs';
    *{$key} = $sub;
}

{
    my $spec = { order_by   => SCALAR_TYPE( default => 'name' ),
                 sort_order => SCALAR_TYPE( default => 'ASC' ),
                 page       => SCALAR_TYPE( default => 1 ),
                 limit      => SCALAR_TYPE( default => 20 ),
               };
    sub set_cursor_params
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        $self->{cursor_params} = \%p;
    }
}

sub users
{
    my $self = shift;

    my %p = $self->cursor_params();
    $p{start} = ( ( delete $p{page} ) - 1 ) * $p{limit};

    %p = ( %p, $self->_search_constraints() );

    return VegGuide::User->All(%p);
}

sub has_filters
{
    my $self = shift;

    my %constraints = $self->_search_constraints();

    return keys %constraints ? 1 : 0;
}

sub count
{
    my $self = shift;

    return VegGuide::User->Count( $self->_search_constraints() );
}

sub _search_constraints
{
    my $self = shift;

    my %p;
    for my $k ( $self->SearchKeys() )
    {
        $p{$k} = $self->$k()
            if defined $self->$k();
    }

    return %p;
}

sub uri
{
    my $self = shift;
    my $page = shift || $self->page();

    return
        URI::FromHash::uri
            ( path  => '/user',
              query => { $self->_query_params(),
                         page       => $page,
                         limit      => $self->limit(),
                         order_by   => $self->order_by(),
                         sort_order => $self->sort_order(),
                       },
            );
}

sub base_uri
{
    my $self = shift;
    my $page = shift || 1;

    return URI::FromHash::uri( path => '/user' );
}

sub _query_params
{
    my $self = shift;

    my %query;
    for my $k ( $self->SearchKeys() )
    {
        my $val = $self->$k();

        $query{$k} = $val
            if defined $val;
    }

    return %query;
}

sub matching
{
    my $self = shift;

    if ( $self->real_name() )
    {
        return 'a name like ' . $self->real_name();
    }
    elsif ( $self->email_address() )
    {
        return 'an email address like ' . $self->email_address();
    }
}

{
    my %DefaultOrder = ( name          => 'ASC',
                         email_address => 'ASC',
                         signup_date   => 'DESC',
                       );
    sub DefaultSortOrder
    {
        my $class = shift;
        my $order_by = shift;

        return $DefaultOrder{$order_by};
    }
}


1;
