package VegGuide::Search::Vendor::ByName;

use strict;
use warnings;

use base 'VegGuide::Search::Vendor';

use VegGuide::Validate qw( validate_with SCALAR_TYPE );

use URI::Escape qw( uri_escape_utf8 );
use URI::FromHash ();
use VegGuide::Location;
use VegGuide::Schema;

sub SearchParams {
    my $class = shift;

    my %p = $class->SUPER::SearchParams();

    delete $p{open_for};

    return %p;
}

sub SearchKeys {
    my $class = shift;

    return grep { $_ ne 'open_for' } $class->SUPER::SearchKeys();
}

{
    my $spec = { name => SCALAR_TYPE };

    sub new {
        my $class = shift;
        my %p     = validate_with(
            params      => \@_,
            spec        => $spec,
            allow_extra => 1,
        );

        my $name = delete $p{name};

        my $self = $class->SUPER::new(%p);

        $self->{name} = $name;

        $self->_process_sql_query();

        return $self;
    }
}

sub name { $_[0]->{name} }

sub _process_sql_query {
    my $self = shift;

    $self->SUPER::_process_sql_query();

    my $schema = VegGuide::Schema->Schema();

    my $name = $self->name();

    push @{ $self->{where} }, VegGuide::Vendor->NameWhere( $self->name() );
}

sub _exclude_long_closed_vendors {0}

sub _vendor_ids_for_rating {
    my $self = shift;

    return VegGuide::Vendor->VendorIdsWithMinimumRating(
        rating => $self->{rating},
        name   => $self->name(),
    );
}

sub count {
    return VegGuide::Vendor->VendorCount(
        where => $_[0]->{where},
        join  => $_[0]->{join},
    );
}

sub _cursor {
    my $self = shift;

    return VegGuide::Vendor->VendorsWhere(
        join  => $self->{join},
        where => $self->{where},
        @_,
    );
}

sub title {
    my $self = shift;

    return 'Entries matching "' . $self->name() . q{"};
}

sub map_uri {
    my $self = shift;

    return URI::FromHash::uri( $self->_uri_base_params('map') );
}

sub printable_uri {
    my $self = shift;

    return URI::FromHash::uri( $self->_uri_base_params('printable') );
}

sub uri {
    my $self = shift;
    my $page = shift || $self->page();

    return URI::FromHash::uri(
        $self->_uri_base_params(),
        query => {
            page       => $page,
            limit      => $self->limit(),
            order_by   => $self->order_by(),
            sort_order => $self->sort_order(),
        },
    );
}

sub base_uri {
    my $self = shift;

    return URI::FromHash::uri( $self->_uri_base_params(@_) );
}

sub _uri_base_params {
    my $self = shift;
    my $suffix = shift || 'filter';

    my @path = '';
    push @path, qw( entry search );
    push @path, uri_escape_utf8( $self->name() );
    push @path, $suffix;

    if ( my $pq = $self->_path_query() ) {
        push @path, $pq;
    }

    return ( path => join '/', @path );
}

1;
