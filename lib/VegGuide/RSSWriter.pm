package VegGuide::RSSWriter;

use strict;
use warnings;

use File::Temp;
use HTML::Entities qw( encode_entities );
use URI::FromHash qw( uri );
use VegGuide::Client;
use VegGuide::Config;
use VegGuide::SiteURI qw( entry_uri entry_review_uri region_uri );
use VegGuide::Util;
use XML::SAX::Writer;
use XML::Generator::RSS10;
use XML::Generator::RSS10::cc;
use XML::Generator::RSS10::dc;
use XML::Generator::RSS10::regveg;

use VegGuide::Validate qw( validate SCALAR BOOLEAN );

sub new {
    my $class = shift;

    my $fh = File::Temp->new();

    # shuts up "wide character in print" warnings
    binmode $fh, ':encoding(UTF-8)';

    my $w = XML::SAX::Writer->new( Output => $fh );
    my $g = XML::Generator::RSS10->new(
        Handler => $w,
        modules => [ 'cc', 'dc', 'regveg' ],
        pretty  => 1,
    );

    my $client = VegGuide::Client->new_from_params(
        show_localized_content => 0,
        encoding               => 'utf8',
        show_utf8              => 1,
        preferred_locale       => 'en_US',
    );

    my $self = bless {
        @_,
        g  => $g,
        c  => $client,
        fh => $fh,
    }, $class;

    my $now = DateTime->now( time_zone => 'UTC' );
    $self->{w3cdtf_now}   = DateTime::Format::W3CDTF->format_datetime($now);
    $self->{current_year} = $now->year;

    return $self;
}

sub fh { $_[0]->{fh} }

sub add_location_for_data_feed {
    my $self = shift;
    my %p    = validate(
        @_, {
            location      => { isa  => 'VegGuide::Location' },
            raw_wiki_text => { type => BOOLEAN, default => 0 },
        },
    );

    my $location = delete $p{location};
    my $vendors  = $location->descendant_vendors;

    while ( my $vendor = $vendors->next ) {
        $self->add_vendor_for_data_feed( vendor => $vendor, %p );
    }

    unless ( $vendors->count() ) {
        $self->{g}->item(
            title => 'No entries in this region',
            link  => region_uri( location => $location, with_host => 1 ),
            dc    => {
                date => DateTime::Format::W3CDTF->format_datetime(
                    DateTime->now()
                ),
            },

        );
    }

    my $description = 'Data feed of entries for ' . $location->name;
    $description .= ', ' . $location->parent->name if $location->parent;
    $description .= '.';

    $self->location_channel( $location, $description );
}

sub location_channel {
    my $self        = shift;
    my $location    = shift;
    my $description = shift;

    $self->{g}->channel(
        title       => "VegGuide.Org: " . $location->name,
        link        => region_uri( location => $location, with_host => 1 ),
        description => $description,
        dc          => {
            publisher => 'Compassionate Action for Animals',
            rights    => "Copyright 2002 - $self->{current_year} "
                . " Compassionate Action for Animals",
            date => $self->{w3cdtf_now},
        },
        cc => {
            license => 'http://creativecommons.org/licenses/by-sa/3.0/us/'
        },
    );
}

sub site_channel {
    my $self        = shift;
    my $title       = shift;
    my $description = shift;

    $self->{g}->channel(
        title => $title,
        link  => uri(
            scheme => 'http', host => VegGuide::Config->CanonicalWebHostname()
        ),
        description => $description,
        dc          => {
            publisher => 'Compassionate Action for Animals',
            rights    => "Copyright 2002 - $self->{current_year} "
                . " Compassionate Action for Animals",
            date => $self->{w3cdtf_now},
        },
        cc => {
            license => 'http://creativecommons.org/licenses/by-sa/3.0/us/'
        },
    );
}

sub add_vendor_for_data_feed {
    my $self = shift;
    my %p    = validate(
        @_, {
            vendor        => { isa  => 'VegGuide::Vendor' },
            raw_wiki_text => { type => BOOLEAN, default => 0 },
        },
    );

    my %item = $self->_vendor_basic_item( $p{vendor} );

    my %rv;

    foreach my $f (
        qw( phone address1 address2
        neighborhood directions
        city region postal_code home_page
        latitude longitude )
        ) {
        my $char_data = $p{vendor}->$f();

        next unless defined $char_data && $char_data =~ /\S/;

        ( my $elt = $f ) =~ s/_/-/g;

        $rv{$elt} = $char_data;
    }

    {
        my $char_data = $p{vendor}->long_description;
        if ( defined $char_data && $char_data =~ /\S/ ) {
            $rv{'long-description'}
                = $p{raw_wiki_text}
                ? $char_data
                : VegGuide::Util::text_to_html( text => $char_data );
        }
    }

    $rv{country} = $p{vendor}->location->country;

    my ( $average, $rating_count ) = $p{vendor}->weighted_rating_and_count;

    if ( $average && $rating_count ) {
        $rv{'average-rating'} = $average;
        $rv{'rating-count'}   = $rating_count;
    }

    $rv{'price-range'} = $p{vendor}->price_range->description();

    $rv{'price-range-number'} = $p{vendor}->price_range->display_order;

    unless ( $p{vendor}->is_organization() ) {
        $rv{'veg-level'}        = $p{vendor}->veg_description;
        $rv{'veg-level-number'} = $p{vendor}->veg_level;
    }

    foreach my $f (
        qw( allows_smoking accepts_reservations is_wheelchair_accessible )) {
        ( my $elt = $f ) =~ s/_/-/g;

        my $value = $p{vendor}->$f();
        $rv{$elt} = (
              $value         ? 'yes'
            : defined $value ? 'no'
            : 'unknown'
        );
    }

    foreach my $f (qw( creation_datetime last_modified_datetime )) {
        ( my $elt = $f ) =~ s/_/-/g;

        my $dt = DateTime::Format::MySQL->parse_datetime( $p{vendor}->$f() );
        $dt->set_time_zone('UTC');
        $rv{$elt} = DateTime::Format::W3CDTF->format_datetime($dt);
    }

    my @cats = map { $_->name } $p{vendor}->categories;
    $rv{categories} = \@cats if @cats;

    my @cuisines = map { $_->name } $p{vendor}->cuisines;
    $rv{cuisines} = \@cuisines if @cuisines;

    if ( $p{vendor}->is_cash_only() ) {
        $rv{'is-cash-only'} = 'yes';
    }
    else {
        my @payment_options = map { $_->name } $p{vendor}->payment_options;
        $rv{'payment-options'} = \@payment_options if @payment_options;
    }

    my @attributes = map { $_->name } $p{vendor}->attributes;
    $rv{features} = \@attributes if @attributes;

    $rv{'edit-link'} = entry_uri( vendor => $p{vendor}, path => 'edit_form',
        with_host => 1 );

    $rv{'edit-hours-link'}
        = entry_uri( vendor => $p{vendor}, path => 'edit_hours_form',
        with_host => 1 );

    $rv{'read-reviews-link'} = $self->_vendor_reviews_link( $p{vendor} );

    $rv{'write-review-link'}
        = entry_uri( vendor => $p{vendor}, path => 'review_form',
        with_host => 1 );

    if ( my $uri = $p{vendor}->map_uri() ) {
        $rv{'map-link'} = $uri;
    }

    $rv{'region-link'} = region_uri( location => $p{vendor}->location() );

    $rv{'region-name'} = $p{vendor}->location->name;

    my $image = $p{vendor}->first_image();
    if ( $image && $image->exists() ) {
        $rv{'image-link'} = $image->small_uri();
        $rv{'image-x'}    = $image->small_width();
        $rv{'image-y'}    = $image->small_height();
    }

    $rv{hours} = [ $p{vendor}->hour_sets_by_day ];

    # include reviews ?

    $self->{g}->item(
        %item,
        dc => {
            date => DateTime::Format::W3CDTF->format_datetime(
                $p{vendor}->creation_datetime_object->set_time_zone('UTC')
            ),
        },
        regveg => \%rv,
    );
}

sub _vendor_basic_item {
    my $self               = shift;
    my $vendor             = shift;
    my $expand_description = shift;

    my $view_link = $self->_vendor_view_link($vendor);

    my $description;
    if ($expand_description) {
        if ( $vendor->long_description ) {
            $description = VegGuide::Util::text_to_html(
                text => $vendor->long_description );
        }
        else {
            $description .= "<p>\n";
            $description .= encode_entities( $vendor->short_description );
            $description .= "\n</p>\n";
        }

        $description .= "<p>\n";
        $description .= '<b>' . $vendor->veg_description . '</b>';
        $description .= "\n</p>\n";

        if ( $vendor->address1 || $vendor->city_region_postal_code ) {
            $description .= "<p>\n";

            if ( $vendor->address1 ) {
                $description .= encode_entities( $vendor->address1 );
                $description .= "<br />\n";
            }

            if ( $vendor->address2 ) {
                $description .= encode_entities( $vendor->address2 );
                $description .= "<br />\n";
            }

            my $crpc = $vendor->city_region_postal_code;
            if ($crpc) {
                $description .= encode_entities($crpc);
                $description .= "<br />\n";
            }

            $description .= "\n</p>\n";
        }
    }
    else {
        $description = $vendor->short_description;
    }

    return (
        title       => $vendor->name,
        link        => $view_link,
        description => $description,
    );
}

sub _vendor_view_link {
    my $self   = shift;
    my $vendor = shift;

    return entry_uri( vendor => $vendor, with_host => 1 );
}

sub _vendor_reviews_link {
    my $self   = shift;
    my $vendor = shift;
    my $user   = shift;

    if ($user) {
        return entry_review_uri( vendor => $vendor, user => $user,
            with_host => 1 );
    }
    else {
        return entry_uri( vendor => $vendor, with_host => 1 );
    }
}

sub add_review {
    my $self    = shift;
    my $comment = shift;
    my $vendor  = shift;
    my $user    = shift;

    my $review_link = $self->_vendor_reviews_link( $vendor, $user );

    my $rating = $vendor->rating_from_user($user);

    my $description
        = VegGuide::Util::text_to_html( text => $comment->comment );
    $description .= "\n<p>($rating / 5)</p>\n"
        if $rating;

    $self->{g}->item(
        title => 'review of '
            . $vendor->name
            . ', written by '
            . $user->real_name,
        link        => $review_link,
        description => $description,
        dc          => {
            date => DateTime::Format::W3CDTF->format_datetime(
                $vendor->creation_datetime_object->set_time_zone('UTC')
            ),
        },
    );
}

sub add_item { shift->{g}->item(@_) }

1;

__END__
