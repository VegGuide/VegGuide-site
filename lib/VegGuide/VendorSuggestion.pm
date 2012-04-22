package VegGuide::VendorSuggestion;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema->VendorSuggestion_t,
);

use VegGuide::Email;
use VegGuide::User;
use VegGuide::Util qw( troolean );
use VegGuide::Vendor;

use VegGuide::Validate qw( validate UNDEF SCALAR BOOLEAN );

sub _init {
    my $self = shift;

    $self->{thawed} = Storable::thaw( $self->suggestion );

    if ( $self->type eq 'core' ) {
        delete $self->{thawed}{sortable_name};
        delete $self->{thawed}{external_unique_id};

        my %cols
            = map { $_ => $self->{thawed}{$_} }
            grep { exists $self->{thawed}{$_} }
            map { $_->name } VegGuide::Vendor->columns();

        $self->{potential} = VegGuide::Vendor->potential(%cols);
    }
}

sub vendor { VegGuide::Vendor->new( object => $_[0]->row_object->vendor ) }

sub user { VegGuide::User->new( object => $_[0]->row_object->user ) }

sub change_exists { exists $_[0]->{thawed}{ $_[1] } }

sub text_changes {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    my %changes;
    foreach my $col ( sort map { $_->name }
        grep { $_->is_character || $_->is_blob } $schema->Vendor_t->columns )
    {
        $changes{$col} = $self->{thawed}{$col}
            if exists $self->{thawed}{$col};
    }

    return \%changes;
}

sub close_date {
    my $self = shift;

    return unless defined $self->{thawed}{close_date};

    return $self->{thawed}{close_date};
}

sub is_cash_only {
    my $self = shift;

    return unless defined $self->{thawed}{is_cash_only};

    return $self->{thawed}{is_cash_only};
}

sub veg_description {
    my $self = shift;

    return unless defined $self->{thawed}{veg_level};

    return $self->{potential}->veg_description;
}

sub category_changes {
    my $self = shift;

    return unless $self->{thawed}{category_id};

    return $self->_add_delete_map( 'category_id', 'VegGuide::Category' );
}

sub cuisine_changes {
    my $self = shift;

    return unless $self->{thawed}{cuisine_id};

    return $self->_add_delete_map( 'cuisine_id', 'VegGuide::Cuisine' );
}

sub payment_option_changes {
    my $self = shift;

    return unless $self->{thawed}{payment_option_id};

    return $self->_add_delete_map( 'payment_option_id',
        'VegGuide::PaymentOption' );
}

sub attribute_changes {
    my $self = shift;

    return unless $self->{thawed}{attribute_id};

    return $self->_add_delete_map( 'attribute_id', 'VegGuide::Attribute' );
}

sub _add_delete_map {
    my $self  = shift;
    my $key   = shift;
    my $class = shift;

    my $meth = $key . q{s};

    my %current = map { $_ => 1 } $self->vendor()->$meth();

    my %new
        = map { $_ => 1 } (
        ref $self->{thawed}{$key}
        ? @{ $self->{thawed}{$key} }
        : $self->{thawed}{$key}
        );

    return (
        add => [
            map { $class->new( $key => $_ ) } grep { !$current{$_} } keys %new
        ],
        remove => [
            map { $class->new( $key => $_ ) } grep { !$new{$_} } keys %current
        ],
    );
}

sub price_range {
    my $self = shift;

    return unless $self->{thawed}{price_range_id};

    return $self->{potential}->price_range;
}

sub is_smoke_free_description {
    my $self = shift;

    return $self->{potential}->is_smoke_free_description();
}

sub is_wheelchair_accessible_description {
    my $self = shift;

    return $self->{potential}->is_wheelchair_accessible_description();
}

sub accepts_reservations_description {
    my $self = shift;

    return $self->{potential}->accepts_reservations_description();
}

sub new_hours_descriptions {
    my $self = shift;

    return VegGuide::Vendor->hours_as_descriptions( sets => $self->{thawed} );
}

sub accept {
    my $self = shift;
    my %p    = validate(
        @_, {
            comment => { type => UNDEF | SCALAR, default => undef },
            user    => { isa  => 'VegGuide::User' },
        },
    );

    if ( $self->type eq 'core' ) {
        $self->vendor->update( %{ $self->{thawed} }, is_suggestion => 1 );
    }
    else {
        $self->vendor->replace_hours( $self->{thawed} );
    }

    $self->_send_email( accepted => 1, %p )
        if $self->user_wants_notification;

    my $log_comment = $self->type eq 'core' ? 'core data' : $self->type;
    $log_comment .= ': accepted by ' . $p{user}->real_name;
    $self->user->insert_activity_log(
        type      => 'suggestion accepted',
        vendor_id => $self->vendor_id,
        comment   => $log_comment,
    );

    $self->delete;
}

sub reject {
    my $self = shift;
    my %p    = validate(
        @_, {
            comment => { type => UNDEF | SCALAR, default => undef },
            user    => { isa  => 'VegGuide::User' },
        },
    );

    $self->_send_email( accepted => 0, %p )
        if $self->user_wants_notification;

    my $log_comment = $self->type eq 'core' ? 'core data' : $self->type;
    $log_comment .= ': rejected by ' . $p{user}->real_name;
    $self->user->insert_activity_log(
        type      => 'suggestion rejected',
        vendor_id => $self->vendor_id,
        comment   => $log_comment,
    );

    $self->delete;
}

sub _send_email {
    my $self = shift;
    my %p    = validate(
        @_, {
            accepted => { type => BOOLEAN },
            comment  => { type => UNDEF | SCALAR, default => undef },
            user     => { isa  => 'VegGuide::User' },
        }
    );

    my %params = (
        vendor => $self->vendor(),
        type => ( $self->type() eq 'core' ? 'core data' : $self->type() ),
        %p,
    );

    my $subject = 'Your suggestion for ';
    $subject .= $self->vendor()->name();
    $subject .= ' was ';
    $subject .= $p{accepted} ? '' : 'not ';
    $subject .= 'accepted';

    VegGuide::Email->Send(
        to       => $self->user()->email_address(),
        subject  => $subject,
        template => 'suggestion-processed',
        params   => \%params,
    );
}

1;
