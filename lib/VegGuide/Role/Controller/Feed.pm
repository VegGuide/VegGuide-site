package VegGuide::Role::Controller::Feed;

use strict;
use warnings;

use Class::Trait 'base';

use File::Basename qw( basename );
use URI::FromHash qw( uri );
use XML::Feed;


my %XMLFeedType = ( rss  => 'RSS',
                    atom => 'Atom',
                  );

sub _serve_feed
{
    my $self = shift;
    my $c    = shift;
    my $feed = shift;
    my $type = shift;

    $c->response()->content_type( 'application/' . $type . '+xml' );

    local $XML::Atom::DefaultVersion = '1.0';

    $c->response()->body( $feed->convert( $XMLFeedType{$type} )->as_xml() );
}


if ( $XML::Feed::VERSION <= 0.12 )
{
    no warnings 'redefine';
    # This monkey patch fixes a problem where summary is empty.
    eval <<'EOF';
package XML::Feed::Entry;

sub convert {
    my $entry = shift;
    my($format) = @_;
    my $new = __PACKAGE__->new($format);
    for my $field (qw( title link content summary category author id issued modified )) {
        my $val = $entry->$field();
        next unless defined $val;
        next if ref $val && $val->can('body') && ! defined $val->body();
        $new->$field($val);
    }
    $new;
}
EOF
}

sub _serve_rss_data_file
{
    my $self = shift;
    my $c    = shift;
    my $file = shift;

    unless ( -f $file )
    {
        $c->response()->status(404);
        $c->detach();
    }

    if ( $c->engine()->isa('Catalyst::Engine::Apache') )
    {
        $c->redirect( uri( path => '/static/rss/' . basename($file) ) );
    }

    open my $fh, '<', $file
        or die "Cannot read $file: $!";

    $c->response()->content_type( 'application/rss+xml' );
    $c->response()->content_length( -s $file );
    $c->response()->body($fh);
}

1;
