package VegGuide::Plugin::Session::Store::VegGuide;

use strict;
use warnings;

use base 'Catalyst::Plugin::Session::Store::DBI';

use VegGuide::Schema;

sub _session_dbic_connect {
    my $self = shift;

    $self->_session_dbh( VegGuide::Schema->Connect()->driver()->handle() );
}

sub store_session_data {
    my $self = shift;

    return unless $self->has_session_object();

    return if $_[0] =~ /^expires/;

    $self->SUPER::store_session_data(@_);
}

1;
