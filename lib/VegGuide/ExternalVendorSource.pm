package VegGuide::ExternalVendorSource;

use strict;
use warnings;

use LWP::Simple qw( get );
use XML::Simple qw( :strict );

use VegGuide::Schema;
use VegGuide::AlzaboWrapper
    ( table => VegGuide::Schema->Schema()->ExternalVendorSource_t() );


sub process_feed
{
    my $self = shift;

    my $xml = $self->_get_feed();
    $self->_process_xml($xml);
}

sub _get_feed
{
    my $self = shift;

    return get( $self->feed_uri() );
}

{
    my $Simple = XML::Simple->new( ForceArray => [ 'category' ],
                                   KeyAttr    => 1,
                                 );

    sub _process_xml
    {
        my $self = shift;
        my $xml  = shift;

        my $items = eval { $Simple->XMLin($xml)->{item} };

        $self->_filter_items($items);

        use Data::Dumper; print Dumper $items;
    }
}

sub _filter_items
{
    my $self  = shift;
    my $items = shift;

    return unless $items;

    return unless $self->filter_class();

    $self->_load_filter();

    $self->full_filter_class()->filter($items);
}

sub _load_filter
{
    my $self = shift;

    return if $self->full_filter_class()->can('filter');

    eval 'use ' . $self->full_filter_class();
    die $@ if $@;
}

sub full_filter_class
{
    my $self = shift;

    return join '::', __PACKAGE__, 'Filter', $self->filter_class();
}


1;
