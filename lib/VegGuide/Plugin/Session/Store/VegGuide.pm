package VegGuide::Plugin::Session::Store::VegGuide;

use strict;
use warnings;

use base 'Catalyst::Plugin::Session::Store::DBI';

use VegGuide::Schema;


sub _session_dbic_connect
{
    my $self = shift;

    $self->_session_dbh( VegGuide::Schema->Connect()->driver()->handle() );
}

sub store_session_data
{
    my $self = shift;
    my $key  = shift;
    my $data = shift;

    return if $key =~ /^expires:/;

    return unless defined $data && grep { ! /^__/ } keys %{ $data };

    $self->SUPER::store_session_data( $key, $data );
}


1;
