package VegGuide::Search::Vendor::ByLatLong;

use strict;
use warnings;

use base 'VegGuide::Search::Vendor';

use VegGuide::Validate qw( validate_with SCALAR_TYPE POS_INTEGER_TYPE );

use Lingua::EN::Inflect qw( PL );
use URI::Escape qw( uri_escape );
use URI::FromHash ();
use VegGuide::GreatCircle qw( lat_long_min_max );
use VegGuide::Location;
use VegGuide::Schema;


sub SearchParams
{
    my $class = shift;

    my %p = $class->SUPER::SearchParams();

    delete $p{open_for};

    return %p;
}

sub SearchKeys
{
    my $class = shift;

    return grep { $_ ne 'open_for' } $class->SUPER::SearchKeys();
}

{
    my $spec = { address   => SCALAR_TYPE,
                 distance  => POS_INTEGER_TYPE( default => 5 ),
                 unit      => SCALAR_TYPE( regex => qr/^(?:mile|km)$/, default => 'mile' ),
                 latitude  => SCALAR_TYPE,
                 longitude => SCALAR_TYPE,
               };
    sub new
    {
        my $class = shift;
        my %p = validate_with( params => \@_,
                               spec   => $spec,
                               allow_extra => 1,
                             );

        my @keys = keys %{ $spec };
        my @vals = delete @p{ @keys };

        my $self = $class->SUPER::new(%p);

        @{ $self }{@keys} = @vals;

        $self->_process_sql_query();

        return $self;
    }
}

sub address   { $_[0]->{address} }
sub distance  { $_[0]->{distance} }
sub unit      { $_[0]->{unit} }
sub latitude  { $_[0]->{latitude} }
sub longitude { $_[0]->{longitude} }

sub set_distance
{
    my $self = shift;

    $self->{distance} = shift;

    $self->_process_sql_query();
}

sub set_unit
{
    my $self = shift;

    $self->{unit} = shift;

    $self->_process_sql_query();
}

sub _default_order_by { 'distance' }

sub _process_sql_query
{
    my $self = shift;

    $self->SUPER::_process_sql_query();

    my $schema = VegGuide::Schema->Schema();

    push @{ $self->{where} },
        VegGuide::Vendor->LatitudeLongitudeMinMaxWhere( $self->_lat_long_min_max() );
}

sub _lat_long_min_max
{
    my $self = shift;

    return
        lat_long_min_max( latitude  => $self->latitude(),
                          longitude => $self->longitude(),
                          distance  => $self->distance(),
                          unit      => $self->unit(),
                        );
}

sub _vendor_ids_for_rating
{
    my $self = shift;

    return
        VegGuide::Vendor->VendorIdsWithMinimumRating
            ( rating                     => $self->{rating},
              latitude_longitude_min_max => $self->_lat_long_min_max(),
            );
}

sub count
{
    return
        VegGuide::Vendor->VendorCount
            ( where => $_[0]->{where},
              join  => $_[0]->{join},
            );
}

sub _cursor
{
    my $self = shift;

    return
        VegGuide::Vendor->VendorsWhere
            ( join  => $self->{join},
              where => $self->{where},
              lat_long => [ $self->latitude(), $self->longitude() ],
              unit     => $self->unit(),
              @_,
            );
}

sub title
{
    my $self = shift;

    return
        ( 'Entries within '
          . $self->distance() . q{ }
          . PL( $self->unit(), $self->distance() )
          . ' of ' . $self->address()
        );
}

sub map_uri
{
    my $self = shift;

    return
        URI::FromHash::uri( $self->_uri_base_params('map') );
}

sub printable_uri
{
    my $self = shift;

    return
        URI::FromHash::uri( $self->_uri_base_params('printable') );
}

sub uri
{
    my $self = shift;
    my $page = shift || $self->page();

    my %params = $self->_uri_base_params();

    $params{query} = { page       => $page,
                       limit      => $self->limit(),
                       order_by   => $self->order_by(),
                       sort_order => $self->sort_order(),
                       %{ $params{query} },
                     };

    return URI::FromHash::uri(%params);
}

sub base_uri
{
    my $self = shift;

    return URI::FromHash::uri( $self->_uri_base_params(@_) );
}

sub _uri_base_params
{
    my $self   = shift;
    my $suffix = shift || 'filter';

    my @path = '';
    push @path, qw( entry near );
    push @path, uri_escape( join ',', $self->latitude(), $self->longitude() );
    push @path, $suffix;

    if ( my $pq = $self->_path_query() )
    {
        push @path, $pq;
    }

    my %params;
    $params{path} = join '/', @path;

    $params{query} = { address  => $self->address(),
                       distance => $self->distance(),
                       unit     => $self->unit(),
                     };

    return %params;
}


1;
