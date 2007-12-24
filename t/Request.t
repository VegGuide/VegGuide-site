use strict;
use warnings;

use Test::More tests => 6;

use HTTP::Headers;
use VegGuide::Request;


{
    my $request = VegGuide::Request->new();
    $request->{_context} = 'MockContext';
    $request->headers( HTTP::Headers->new );
    $request->parameters( {} );
    $request->method('GET');
    $request->headers->header( 'Accept' => 'text/xml' );

    ok( ! $request->looks_like_browser(),
        'request does not want html display' );
}

{
    my $request = VegGuide::Request->new();
    $request->{_context} = 'MockContext';
    $request->headers( HTTP::Headers->new );
    $request->parameters( {} );
    $request->method('GET');
    $request->headers->header(
        'Accept' =>
        # From Firefox 2.0 when it requests an html page
        'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
    );

    ok( $request->looks_like_browser(),
        'request does want html display' );
}

{
    my $request = VegGuide::Request->new();
    $request->{_context} = 'MockContext';
    $request->headers( HTTP::Headers->new );
    $request->parameters( { 'content-type' => 'text/plain' } );
    $request->method('GET');
    $request->headers->header(
        'Accept' =>
        # From Firefox 2.0 when it requests an html page
        'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
    );

    ok( ! $request->looks_like_browser(),
        'request does want html display' );
}

{
    my $request = VegGuide::Request->new();
    $request->{_context} = 'MockContext';
    $request->headers( HTTP::Headers->new );
    $request->parameters( { 'x-tunneled-method' => 'PUT' } );
    $request->method('GET');

    is( $request->method(), 'PUT',
        'use x-tunneled-method param for GET request' );
}

{
    my $request = VegGuide::Request->new();
    $request->{_context} = 'MockContext';
    $request->headers( HTTP::Headers->new );
    $request->parameters( {} );
    $request->method('PUT');

    is( $request->method(), 'PUT',
        'request method is PUT' );
}

{
    my $request = VegGuide::Request->new();
    $request->{_context} = 'MockContext';
    $request->headers( HTTP::Headers->new );
    $request->parameters( { 'x-tunneled-method' => 'PUT' } );
    $request->method('POST');

    is( $request->method(), 'PUT',
        'request method is PUT (tunneled via POST)' );
}


package MockContext;

sub prepare_body { }
