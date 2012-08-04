package VegGuide::Comment;

use strict;
use warnings;

use parent 'VegGuide::AlzaboWrapper';

use DateTime::Format::RFC3339;
use DateTime::Format::MySQL;
use VegGuide::User;
use VegGuide::Util qw( clean_text );

sub create {
    my $self = shift;
    my %p    = @_;

    clean_text( $p{comment} );

    $self->SUPER::create(%p);
}

sub update {
    my $self = shift;
    my %p    = @_;

    clean_text( $p{comment} );

    $self->SUPER::update(%p);
}

sub user {
    VegGuide::User->new( object => $_[0]->row_object()->user() );
}

sub last_modified_date {
    DateTime::Format::MySQL->parse_datetime( $_[0]->last_modified_datetime() )
        ->ymd();
}

sub rest_data {
    my $self = shift;

    my $dt
        = DateTime::Format::RFC3339->format_datetime(
        $self->last_modified_datetime_object()->clone()
            ->set_time_zone('America/Denver')->set_time_zone('UTC') );

    return {
        body => VegGuide::Util::text_for_rest_response( $self->comment() ),
        last_modified_datetime => $dt,
        user => $self->user()->rest_data( include_related => 0 ),
    };
}

1;
