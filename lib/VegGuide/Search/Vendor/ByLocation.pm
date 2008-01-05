package VegGuide::Search::Vendor::ByLocation;

use strict;
use warnings;

use base 'VegGuide::Search::Vendor';

use VegGuide::Validate qw( validate_with LOCATION_TYPE );

use DateTime;
use VegGuide::Location;
use VegGuide::Schema;
use VegGuide::SiteURI qw( region_uri );


{
    my $spec = { location => LOCATION_TYPE };
    sub new
    {
        my $class = shift;
        my %p = validate_with( params => \@_,
                               spec   => $spec,
                               allow_extra => 1,
                             );

        my $location = delete $p{location};

        my $self = $class->SUPER::new(%p);

        $self->{location} = $location;

        $self->_process_sql_query();

        return $self;
    }
}

sub location { $_[0]->{location} }

sub _open_for
{
    my $self = shift;

    return unless $self->{open_for} && $self->{location}->time_zone;

    push @{ $self->{where} },
        [ VegGuide::Schema->Schema()->Vendor_t->close_date_c, '=', undef ];

    my $vh1 = VegGuide::Schema->Schema()->VendorHours_t->alias;
    my $vh2 = VegGuide::Schema->Schema()->VendorHours_t->alias;

    push @{ $self->{join} },
        ( [ VegGuide::Schema->Schema()->Vendor_t, $vh1 ],
          [ VegGuide::Schema->Schema()->Vendor_t, $vh2 ],
        );

    my $dt = DateTime->now( time_zone => $self->{location}->time_zone );

    push @{ $self->{where} }, VegGuide::Vendor->is_open_where_clause($dt, $vh1);

    my $round_min = 15 - ( $dt->minute() % 15 );
    $dt->add( minutes => $self->{open_for} + $round_min );

    push @{ $self->{where} }, VegGuide::Vendor->is_open_where_clause($dt, $vh2);

    my $until = sprintf( '%d:%02d %s', $dt->strftime( '%I', '%M', '%p' ) );

    $self->{descriptions}{open_for}{long} =
        "which are open until $until or later.";

    $self->{descriptions}{open_for}{short} = $until;

    $self->{path_query}{open_for} = $self->{open_for};
}

sub _vendor_ids_for_rating
{
    my $self = shift;

    return
        VegGuide::Vendor->VendorIdsWithMinimumRating
            ( rating      => $self->{rating},
              location_id => $self->location()->location_id(),
            );
}

sub count
{
    return
        $_[0]->{location}->active_vendor_count
            ( where => $_[0]->{where},
              join  => $_[0]->{join},
            );
}

sub _cursor
{
    my $self = shift;

    return
        $self->{location}->vendors
            ( join  => $self->{join},
              where => $self->{where},
              @_,
            );
}

sub title
{
    my $self = shift;

    return 'Entries in ' . $self->location()->name();
}

sub map_uri
{
    my $self = shift;

    return
        region_uri( $self->_uri_base_params('map') );
}

sub printable_uri
{
    my $self = shift;

    return
        region_uri( $self->_uri_base_params('printable') );
}

sub uri
{
    my $self = shift;
    my $page = shift || $self->page();

    return
        region_uri
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

    return region_uri( $self->_uri_base_params(@_) );
}

sub _uri_base_params
{
    my $self   = shift;
    my $prefix = shift;

    my @path;
    @path = $prefix
        if $prefix;
    push @path, 'filter'
        unless @path;

    if ( my $pq = $self->_path_query() )
    {
        push @path, $pq;
    }

    my %path;
    $path{path} = join '/', @path
        if @path;

    return ( location => $self->location(),
             %path,
           );
}

sub has_addresses
{
    my $self = shift;

    return $self->location()->has_addresses();
}


1;
