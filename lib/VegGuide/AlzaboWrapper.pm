package VegGuide::AlzaboWrapper;

use strict;
use warnings;

use base 'Class::AlzaboWrapper';

use Class::AlzaboWrapper 0.12;

use DateTime::Format::MySQL;
use Encode ();

use VegGuide::Exceptions ('error');

sub import {
    my $class = shift;

    return unless @_;

    my %p = @_;

    my $caller = ( caller(0) )[0];

    my %skip_decode;
    if ( $p{skip_decode} ) {
        %skip_decode
            = map { $_ => 1 }
            ref $p{skip_decode} ? @{ $p{skip_decode} } : $p{skip_decode};
    }

    my @char_cols = (
        grep { !$skip_decode{$_} }
        map  { $_->name }
        grep { $_->is_character || $_->is_blob } $p{table}->columns
    );

    $p{skip} = $p{skip} ? [ @{ $p{skip} }, @char_cols ] : \@char_cols;

    delete $p{skip_decode};

    $class->SUPER::import(
        %p,
        base   => $class,
        caller => $caller,
    );

    $class->_make_char_col_methods( $caller, @char_cols );

    $class->_make_datetime_col_methods( $caller,
        grep { $_->is_date } $p{table}->columns );
}

# This ensures that UTF-8 data coming from MySQL is treated as UTF-8
# by Perl.
sub _make_char_col_methods {
    my $class  = shift;
    my $caller = shift;

    foreach my $c (@_) {
        my $key = '__decoded_' . $c . '__';

        no strict 'refs';

        *{"$caller\::$c"} = sub {
            unless ( exists $_[0]->{$key} ) {
                my $val = $_[0]->row_object->select($c);
                $val = Encode::decode( 'utf-8', $val )
                    unless Encode::is_utf8($val);
                $_[0]->{$key} = $val;
            }
            $_[0]->{$key};
        };

        $class->_RecordAttributeCreation( $caller => $c );
    }
}

sub _make_datetime_col_methods {
    my $self   = shift;
    my $caller = shift;
    my @cols   = @_;

    foreach my $c (@cols) {
        if ( $c->is_datetime ) {
            my $name = $c->name;
            my $key  = '__datetime_' . $name . '__';

            no strict 'refs';
            *{"$caller\::${name}_object"} = sub {
                my $val = $_[0]->$name();
                return unless defined $_[0]->$name();
                return if $val eq '0000-00-00 00:00:00';
                $_[0]->{$key} ||= DateTime::Format::MySQL->parse_datetime(
                    $_[0]->$name );
                return $_[0]->{$key};
            };
        }
        else {
            my $name = $c->name;
            my $key  = '__date_' . $name . '__';

            no strict 'refs';
            *{"$caller\::${name}_object"} = sub {
                my $val = $_[0]->$name();
                return unless defined $val;
                return if $val eq '0000-00-00';
                $_[0]->{$key}
                    ||= DateTime::Format::MySQL->parse_date( $_[0]->$name );
                return $_[0]->{$key};
            };
        }
    }
}

sub create {
    my $class = shift;
    my %p     = @_;

    $class->_validate_data( \%p )
        if $class->can('_validate_data');

    return $class->SUPER::create(%p);
}

sub update {
    my $self = shift;
    my %p    = @_;

    $self->_validate_data( \%p )
        if $self->can('_validate_data');

    return $self->SUPER::update(%p);
}

sub IsValidId {
    my $class = shift;

    my @pk = $class->Table->primary_key;

    error "Cannot call IsValidId on $class (multi-column pk)"
        if @pk > 1;

    return $class->Table->row_count( where => [ $pk[0], '=', shift ] );
}

sub Count { $_[0]->Table->row_count }

sub DDS_freeze {
    my $self = shift;

    my $out = ref $self;
    $out .= ': ';

    my @pk_vals;
    for my $pk ( $self->Table()->primary_key() ) {
        push @pk_vals, $pk->name() . ' = ' . $self->select( $pk->name() );
    }

    $out .= join '|', @pk_vals;

    return $out;
}

sub ClearCache {
    VegGuide::Vendor->ClearCache()
        if VegGuide::Vendor->can('ClearCache');
}

1;

__END__
