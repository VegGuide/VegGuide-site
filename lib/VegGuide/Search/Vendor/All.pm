package VegGuide::Search::Vendor::All;

use strict;
use warnings;

use base 'VegGuide::Search::Vendor';

use VegGuide::Validate qw( validate_with LOCATION_TYPE );

use DateTime;
use VegGuide::Location;
use VegGuide::Schema;
use VegGuide::SiteURI qw( site_uri );


{
    my $spec = { location => LOCATION_TYPE };
    sub new
    {
        my $class = shift;

        my $self = $class->SUPER::new(@_);

        $self->_process_sql_query();

        return $self;
    }
}

sub _default_order_by { 'created' }

sub count
{
    return VegGuide::Vendor->ActiveVendorCount();
}

sub _cursor
{
    my $self = shift;

    return VegGuide::Vendor->ActiveVendors(@_);
}

sub title
{
    my $self = shift;

    return 'All entries';
}

sub has_mappable_vendors { 0 }

sub printable_uri
{
    my $self = shift;

    return
        site_uri( $self->_uri_base_params('printable') );
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

    return ( path => '/entry/',
           );
}


1;
