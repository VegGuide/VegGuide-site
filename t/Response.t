use strict;
use warnings;

use Test::More tests => 3;

use VegGuide::Plugin::ResponseAttributes;
use VegGuide::Response;

my $response = VegGuide::Response->new();

VegGuide::Plugin::ResponseAttributes->prepare($context);
$response->{_context} = FakeContext->new('/my/uri');

isa_ok( $response->breadcrumbs(),     'VegGuide::Breadcrumbs' );
isa_ok( $response->keywords(),        'VegGuide::Keywords' );
isa_ok( $response->alternate_links(), 'VegGuide::AlternateLinks' );

package FakeContext;

sub new {
    my $class = shift;
    my $uri   = shift;

    return bless \$uri, $class;
}

sub uri { ${ $_[0] } }
