use strict;
use warnings;

use Test::More;

use VegGuide::AlternateLinks;

my $links = VegGuide::AlternateLinks->new();
isa_ok( $links, 'VegGuide::AlternateLinks' );

$links->add(
    mime_type => 'text/foo',
    uri       => '/a/uri',
    title     => 'yadda',
);

my @links = $links->all();
is( scalar @links, 1, 'one link returned' );

is( $links[0]->mime_type(), 'text/foo', 'mime_type() for link object' );
is( $links[0]->uri(),       '/a/uri',   'uri() for link object' );
is( $links[0]->title(),     'yadda',    'title() for link object' );

$links->add(
    mime_type => 'application/bar',
    uri       => '/b/uri',
    title     => 'foo',
);

@links = $links->all();
is( scalar @links, 2, 'two alternate_links returned' );

is( $links[0]->mime_type(), 'text/foo', 'mime_type() for link object' );
is( $links[0]->uri(),       '/a/uri',   'uri() for first link object' );
is( $links[0]->title(),     'yadda',    'title() for first link object' );

is(
    $links[1]->mime_type(), 'application/bar',
    'mime_type() for link object'
);
is( $links[1]->uri(),   '/b/uri', 'uri() for second link object' );
is( $links[1]->title(), 'foo',    'title() for second link object' );

done_testing();
