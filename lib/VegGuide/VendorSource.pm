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

# I'd like to use XML::Simple's strict mode but doing so breaks
# Net::OpenID::Yadis, because strict mode is set for all users of
# XML::Simple.
use XML::Simple;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema()->VendorSource_t() );

use constant DEBUG => 1;

sub process_feed {
    my $self = shift;

    warn "Processing feed at ", $self->feed_uri(), "\n"
        if DEBUG;

    my $xml = $self->_get_feed();

    unless ($xml) {
        warn 'Could not find feed at ' . $self->feed_uri() . "\n";
        return;
    }

    $self->_process_xml($xml);
}

sub _get_feed {
    my $self = shift;

    return get( $self->feed_uri() );
}

{
    my $Simple = XML::Simple->new(
        ForceArray => ['category'],
        KeyAttr    => 1,
    );

    sub _process_xml {
        my $self = shift;
        my $xml  = shift;

        my $items = eval { $Simple->XMLin($xml)->{item} };

        return unless $items;

        $self->_filter_items($items);

        $self->_remove_excluded_items($items);

        my $schema = VegGuide::Schema->Connect();

        # This is broken, apparently I'm using local times in the
        # DBMS, which is really, really wrong.
        my $processed = DateTime::Format::MySQL->format_datetime(
            DateTime->now( time_zone => 'local' ) );

        warn "Processed dt is $processed\n"
            if DEBUG;

        # We need to wrap the whole thing in a transaction so that if
        # updates fail, then we don't update the
        # last_processed_datetime for the source.
        eval {
            $schema->begin_work();

            $self->_update_or_create_vendor( $_, $processed ) for @{$items};

            $self->update( last_processed_datetime => $processed );

            $schema->commit();
        };

        if ( my $e = $@ ) {
            eval { $schema->rollback() };
            die $e;
        }
    }
}

sub _filter_items {
    my $self  = shift;
    my $items = shift;

    return unless $items;

    return unless $self->filter_class();

    $self->_load_filter();

    $self->_full_filter_class()->filter($items);
}

sub _load_filter {
    my $self = shift;

    return if $self->_full_filter_class()->can('filter');

    eval 'use ' . $self->_full_filter_class();
    die $@ if $@;
}

sub _full_filter_class {
    my $self = shift;

    return join '::', __PACKAGE__, 'Filter', $self->filter_class();
}

sub _remove_excluded_items {
    my $self  = shift;
    my $items = shift;

    my @excluded_ids = $self->_excluded_ids()
        or return;

    my %id = map { $_ => 1 } @excluded_ids;

    my @save;
    for my $item ( @{$items} ) {
        if ( $id{ $item->{external_unique_id} } ) {
            warn
                "Ignoring excluded item - $item->{name} ($item->{external_unique_id})\n"
                if DEBUG;
            next;
        }

        push @save, $item;
    }

    @{$items} = @save;
}

sub add_excluded_id {
    my $self = shift;
    my $id   = shift;

    my $schema = VegGuide::Schema->Connect();

    $schema->VendorSourceExcludedId_t()->insert(
        values => {
            vendor_source_id   => $self->vendor_source_id(),
            external_unique_id => $id,
        },
    );
}

sub _excluded_ids {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorSourceExcludedId_t()->function(
        select => $schema->VendorSourceExcludedId_t()->external_unique_id_c(),
        where  => [
            $schema->VendorSourceExcludedId_t()->vendor_source_id_c(),
            '=', $self->vendor_source_id()
        ],
    );
}

{
    my $User = VegGuide::User->new( real_name => 'VegGuide.Org' );

    sub _update_or_create_vendor {
        my $self      = shift;
        my $item      = shift;
        my $processed = shift;

        my $vendor = VegGuide::Vendor->new(
            external_unique_id => $item->{external_unique_id},
            vendor_source_id   => $self->vendor_source_id(),
        );

        $self->_set_location_for_item($item)
            or return;

        unless ($vendor) {

            # XXX - is it likely that we will ever have non-US feeds?
            my $geocoder = VegGuide::Geocoder->new( country => 'USA' );

            my %p = (
                map { $_ => $item->{$_} }
                    grep { !string_is_empty( $item->{$_} ) }
                    qw( address1 city region postal_code )
            );

            # I think Google is not happy when we hammer it for
            # addresses or something, let's see if this helps.
            sleep 1;
            my $result = $geocoder->geocode(%p);

            if ($result) {
                $vendor = VegGuide::Vendor->new(
                    name              => $item->{name},
                    canonical_address => $result->canonical_address(),
                );
            }
        }

        my $id
            = join ' - ', grep {defined} (
            $vendor
            ? ( $vendor->name(), $vendor->city() )
            : ( $item->{name}, $item->{city} )
            );

        if ( $vendor
            && !$vendor->external_unique_id() ) {
            warn "$id was created before we started importing this feed\n"
                if DEBUG;
            return;
        }

        if (   $vendor
            && $self->last_processed_datetime()
            && $vendor->last_modified_datetime_object()
            > $self->last_processed_datetime_object() ) {
            warn
                "$id was updated since last processed datetime (excluding from future feed updates)\n"
                if DEBUG;

            $self->add_excluded_id( $vendor->external_unique_id() );

            return;
        }

        eval {
            if ($vendor) {
                warn "Updating $id\n"
                    if DEBUG;
                $vendor->update(
                    %{$item},
                    user                   => $User,
                    vendor_source_id       => $self->vendor_source_id(),
                    last_modified_datetime => $processed,
                );
            }
            else {
                warn "Creating $id\n"
                    if DEBUG;
                VegGuide::Vendor->create(
                    %{$item},
                    vendor_source_id       => $self->vendor_source_id(),
                    user_id                => $User->user_id(),
                    creation_datetime      => $processed,
                    last_modified_datetime => $processed,
                );
            }
        };

        if ( my $e = $@ ) {
            if ( $e->can('errors') ) {
                warn "$_\n" for @{ $e->errors() };
            }

            warn $e;
        }
    }
}

sub _set_location_for_item {
    my $self = shift;
    my $item = shift;

    my $location = $self->_full_filter_class()->_location_for_item($item);

    unless ($location) {
        warn
            "Could not determine location for $item->{name} ($item->{external_unique_id})\n";
        return 0;
    }

    $item->{location_id} = $location->location_id();
    $item->{region}      = $location->parent()->name();

    return 1;
}

sub All {
    my $class = shift;

    return $class->cursor(
        $class->table()->all_rows( order_by => $class->table()->name_c() ) );
}

sub FilterClasses {
    return
        map { ( split /::/, $_ )[-1] }
        VegGuide::VendorSource::Filter->subclasses();
}

1;
