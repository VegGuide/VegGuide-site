package VegGuide::Request;

use strict;
use warnings;

use base 'Catalyst::Request::REST::ForBrowsers';

use DateTime::Format::Natural;
use HTTP::Headers::Util qw(split_header_words);
use List::MoreUtils qw( all );
use Scalar::Util qw( looks_like_number );
use VegGuide::Util qw( string_is_empty );

use VegGuide::Validate qw( validate validate_pos
    HASHREF_TYPE BOOLEAN_TYPE
    SCALAR_OR_ARRAYREF_TYPE );

sub location_data {
    my $self = shift;

    my %data = $self->_params_for_classes( classes => 'VegGuide::Location' );

    $data{skip_duplicate_check} = $self->param('skip_duplicate_check');

    delete @data{ 'parent_location_id', 'location_id', 'user_id' };

    return %data;
}

my $parser = DateTime::Format::Natural->new( format => 'mm-dd-yyyy' );

sub vendor_data {
    my $self = shift;

    my %data = $self->_params_for_classes( classes => 'VegGuide::Vendor' );

    my $params = $self->parameters();

    for my $k (qw( new_neighborhood new_localized_neighborhood category_id ))
    {
        $data{$k} = $params->{$k}
            if defined $params->{$k};
    }

    for my $k ( grep { exists $params->{$_} }
        qw( cuisine_id payment_option_id attribute_id ) ) {
        $data{$k} = defined $params->{$k} ? $params->{$k} : [];
    }

    $data{payment_option_id} = []
        if $data{is_cash_only};

    if ( $data{close_date} ) {
        if ( $data{close_date} eq 'open' ) {
            $data{close_date} = undef;
        }
        else {
            my $dt = $parser->parse_datetime( $data{close_date} );
            if ($dt) {
                $data{close_date} = $dt->ymd();
            }
            else {
                delete $data{close_date};
            }
        }
    }

    delete $data{vendor_id};

    return %data;
}

sub user_data {
    my $self = shift;

    my %data = $self->_params_for_classes( classes => 'VegGuide::User' );

    my $params = $self->parameters();
    $data{password2} = $params->{password2}
        if defined $params->{password2};

    delete @data{ 'password', 'password2' }
        if all { string_is_empty($_) } @data{ 'password', 'password2' };

    return %data;
}

sub locale_data {
    my $self = shift;

    return $self->_params_for_classes( classes => 'VegGuide::Locale' );
}

sub vendor_source_data {
    my $self = shift;

    return $self->_params_for_classes( classes => 'VegGuide::VendorSource' );
}

sub skin_data {
    my $self = shift;

    my %data = $self->_params_for_classes( classes => 'VegGuide::Skin' );

    $data{home_location_id} = $self->param('location_id');

    return %data;
}

{
    my $spec = {
        classes    => SCALAR_OR_ARRAYREF_TYPE,
        include_pk => BOOLEAN_TYPE( default => 0 ),
    };

    sub _params_for_classes {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $params = $self->parameters();

        my @c = ref $p{classes} ? @{ $p{classes} } : $p{classes};

        my %data;
        foreach my $col ( map { $_->columns() } @c ) {
            next if $col->is_primary_key() && !$p{include_pk};

            my $name = $col->name();

            next unless exists $params->{$name};

            $data{$name} = $params->{$name};

            if ( defined $data{$name} && $data{$name} eq '' ) {
                if (   $col->is_character()
                    || $col->is_date()
                    || $col->is_datetime() ) {
                    $data{$name} = undef;
                }
                elsif ($col->type() eq 'TINYINT'
                    && $col->length() == 1
                    && $col->nullable() ) {
                    $data{$name} = undef;
                }
                else {
                    $data{$name} = 0;
                }
            }
        }

        return %data;
    }
}

# This is a monkey patch to shut up some warnings.
sub accepted_content_types {
    my $self = shift;

    return $self->{content_types} if $self->{content_types};

    my %types;

    # First, we use the content type in the HTTP Request.  It wins all.
    $types{ $self->content_type } = 3
        if $self->content_type;

    if ( $self->method eq "GET" && $self->param('content-type') ) {

        $types{ $self->param('content-type') } = 2;
    }

    # Third, we parse the Accept header, and see if the client
    # takes a format we understand.
    #
    # This is taken from chansen's Apache2::UploadProgress.
    if ( $self->header('Accept') ) {
        $self->accept_only(1) unless keys %types;

        my $accept_header = $self->header('Accept');
        my $counter       = 0;

        foreach my $pair ( split_header_words($accept_header) ) {
            my ( $type, $qvalue ) = @{$pair}[ 0, 3 ];
            next if $types{$type};

            unless ( defined $qvalue && looks_like_number($qvalue) ) {
                $qvalue = 1 - ( ++$counter / 1000 );
            }

            $types{$type} = sprintf( '%.3f', $qvalue );
        }
    }

    return $self->{content_types}
        = [ sort { $types{$b} <=> $types{$a} } keys %types ];
}

1;
