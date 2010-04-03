package VegGuide::Comment;

use strict;
use warnings;

use base 'VegGuide::AlzaboWrapper';

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

1;
