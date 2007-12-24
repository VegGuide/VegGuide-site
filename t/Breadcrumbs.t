use strict;
use warnings;

use Test::More tests => 12;

use VegGuide::Breadcrumbs;


my $req = FakeRequest->new( '/my/path' );
my $bc = VegGuide::Breadcrumbs->new($req);
isa_ok( $bc, 'VegGuide::Breadcrumbs' );

$bc->add( uri   => '/a/uri',
          label => 'yadda',
        );

my @bc = $bc->all();
is( scalar @bc, 1, 'one breadcrumb returned' );

is( $bc[0]->uri(), '/a/uri', 'uri() for breadcrumb object' );
is( $bc[0]->label(), 'yadda', 'label() for breadcrumb object' );

$bc->add( uri   => '/b/uri',
          label => 'foo',
        );

@bc = $bc->all();
is( scalar @bc, 2, 'two breadcrumbs returned' );

is( $bc[0]->uri(), '/a/uri', 'uri() for first breadcrumb object' );
is( $bc[0]->label(), 'yadda', 'label() for first breadcrumb object' );

is( $bc[1]->uri(), '/b/uri', 'uri() for second breadcrumb object' );
is( $bc[1]->label(), 'foo', 'label() for second breadcrumb object' );

$bc->add_standard_breadcrumb('label');

@bc = $bc->all();
is( scalar @bc, 3, 'three breadcrumbs returned' );

is( $bc[2]->uri(), '/my/path', 'uri() for third breadcrumb object' );
is( $bc[2]->label(), 'label', 'label() for third breadcrumb object' );


package FakeRequest;

use URI;


sub new
{
    my $class = shift;
    my $uri   = shift;

    return bless \$uri, $class;
}

sub uri { URI->new( ${ $_[0] } ) }
