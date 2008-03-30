package VegGuide::VendorSource;

use strict;
use warnings;

use DateTime;
use DateTime::Format::MySQL;
use LWP::Simple qw( get );
use VegGuide::VendorSource::Filter;
use VegGuide::User;
use VegGuide::Util qw( string_is_empty );
use VegGuide::Vendor;
use XML::Simple qw( :strict );

use VegGuide::Schema;
use VegGuide::AlzaboWrapper
    ( table => VegGuide::Schema->Schema()->VendorSource_t() );

use constant DEBUG => 1;


sub process_feed
{
    my $self = shift;

    my $xml = $self->_get_feed();

    unless ($xml)
    {
        warn 'Could not find feed at ' . $self->feed_uri() . "\n";
        return;
    }

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

        return unless $items;

        $self->_filter_items($items);

        my $schema = VegGuide::Schema->Connect();

        # This is broken, apparently I'm using local times in the
        # DBMS, which is really, really wrong.
        my $processed =
            DateTime::Format::MySQL->format_datetime( DateTime->now( time_zone => 'local' ) );

        warn "Processed dt is $processed\n"
            if DEBUG;

        # We need to wrap the whole thing in a transaction so that if
        # updates fail, then we don't update the
        # last_processed_datetime for the source.
        eval
        {
            $schema->begin_work();

            $self->_update_or_create_vendor( $_, $processed ) for @{ $items };

            $self->update( last_processed_datetime => $processed );

            $schema->commit();
        };

        if ( my $e = $@ )
        {
            eval { $schema->rollback() };
            die $e;
        }
    }
}

sub _filter_items
{
    my $self  = shift;
    my $items = shift;

    return unless $items;

    return unless $self->filter_class();

    $self->_load_filter();

    $self->_full_filter_class()->filter($items);
}

sub _load_filter
{
    my $self = shift;

    return if $self->_full_filter_class()->can('filter');

    eval 'use ' . $self->_full_filter_class();
    die $@ if $@;
}

sub _full_filter_class
{
    my $self = shift;

    return join '::', __PACKAGE__, 'Filter', $self->filter_class();
}

{
    my $User = VegGuide::User->new( real_name => 'VegGuide.Org' );
    sub _update_or_create_vendor
    {
        my $self      = shift;
        my $item      = shift;
        my $processed = shift;

        my $vendor =
            VegGuide::Vendor->new
                ( external_unique_id => $item->{external_unique_id},
                  vendor_source_id   => $self->vendor_source_id(),
                );

        unless ($vendor)
        {
            # XXX - is it likely that we will ever have non-US feeds?
            my $geocoder = VegGuide::Geocoder->new( country => 'USA' );

            my %p =
                ( map  { $_ => $item->{$_} }
                  grep { ! string_is_empty( $item->{$_} ) }
                  qw( address1 city region postal_code )
                );

            my $result = $geocoder->geocode(%p);

            if ($result)
            {
                $vendor = VegGuide::Vendor->new( name              => $item->{name},
                                                 canonical_address => $result->canonical_address(),
                                                 location_id       => $item->{location_id},
                                               );
            }
        }

        my $id = $vendor ? $vendor->name() . ' - ' . $vendor->city() : $item->{name} . ' - ' . $item->{city};

        if ( $vendor
             && ! $vendor->external_unique_id() )
        {
            warn "$id was created before we started importing this feed\n"
                if DEBUG;
            return;
        }


        if ( $vendor
             && $self->last_processed_datetime()
             && $vendor->last_modified_datetime_object() > $self->last_processed_datetime_object()
           )
        {
            warn "$id was updated since last processed datetime\n"
                if DEBUG;
            return;
        }

        eval
        {
            if ($vendor)
            {
                warn "Updating $id\n"
                    if DEBUG;
                $vendor->update( %{ $item },
                                 user                   => $User,
                                 vendor_source_id       => $self->vendor_source_id(),
                                 last_modified_datetime => $processed,
                               );
            }
            else
            {
                warn "Creating $id\n"
                    if DEBUG;
                VegGuide::Vendor->create( %{ $item },
                                          vendor_source_id       => $self->vendor_source_id(),
                                          user_id                => $User->user_id(),
                                          creation_datetime      => $processed,
                                          last_modified_datetime => $processed,
                                        );
            }
        };

        if ( my $e = $@ )
        {
            if ( $e->can('errors') )
            {
                warn "$_\n" for @{ $e->errors() };
            }
            elsif ( $e->can('error') )
            {
                warn $e->error();
            }
            else
            {
                warn $e;
            }
        }
    }
}

sub All
{
    my $class = shift;

    return
        $class->cursor
            ( $class->table()->all_rows( order_by => $class->table()->name_c() ) );
}

sub FilterClasses
{
    return map { ( split /::/, $_ )[-1] } VegGuide::VendorSource::Filter->subclasses();
}

1;
