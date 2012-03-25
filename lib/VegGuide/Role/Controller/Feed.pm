package VegGuide::Role::Controller::Feed;

use strict;
use warnings;
use namespace::autoclean;

use File::Basename qw( basename );
use URI::FromHash qw( uri );

use Moose::Role;

my %XMLFeedType = (
    rss  => 'RSS',
    atom => 'Atom',
);

sub _serve_feed {
    my $self = shift;
    my $c    = shift;
    my $feed = shift;
    my $type = shift;

    $c->response()->content_type( 'application/' . $type . '+xml' );

    local $XML::Atom::DefaultVersion = '1.0';

    $c->response()->body( $feed->convert( $XMLFeedType{$type} )->as_xml() );
}

sub _serve_rss_data_file {
    my $self = shift;
    my $c    = shift;
    my $file = shift;

    unless ( -f $file ) {
        $c->response()->status(404);
        $c->detach();
    }

    if ( $c->engine()->isa('Catalyst::Engine::Apache') ) {
        $c->redirect_and_detach(
            uri( path => '/static/rss/' . basename($file) ) );
    }

    open my $fh, '<', $file
        or die "Cannot read $file: $!";

    $c->response()->content_type('application/rss+xml');
    $c->response()->content_length( -s $file );
    $c->response()->body($fh);
}

1;
