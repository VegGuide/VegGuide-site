use strict;
use warnings;

use Test::More;

BEGIN {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
}

use VegGuide::Email;

{
    Email::Sender::Simple->default_transport()->clear_deliveries();
    VegGuide::Email->Send(
        to       => 'to@example.com',
        from     => 'from@example.com',
        subject  => 'Testing',
        template => 'forgot-password',
        params   => { uri => 'http://example.com' },
    );

    my @emails = Email::Sender::Simple->default_transport()->deliveries();

    is( scalar @emails, 1, 'one email was sent' );

    my $email = Courriel->parse( text => $emails[0]{email}->as_string() );

    my @to = $email->to();
    is(
        scalar @to,
        1,
        'one To address'
    );
    is(
        $to[0]->address(),
        'to@example.com',
        'check To address'
    );
    is(
        $email->from()->address(),
        'from@example.com',
        'check From address'
    );
    is(
        $email->subject(),
        'Testing',
        'check Subject'
    );
    is(
        $email->headers()->get('Reply-To')->value(),
        q|"VegGuide.Org" <guide@vegguide.org>|,
        'check Reply-To address'
    );
    is(
        $email->headers()->get('X-Sender')->value(),
        'VegGuide::Email',
        'check X-Sender'
    );
    is(
        $email->content_type()->mime_type(),
        'multipart/alternative',
        'check Content-Type'
    );
    ok( $email->headers()->get('Message-ID'), 'header has Message-ID' );
    ok( $email->headers()->get('Date'),       'header has Date' );
}

done_testing();
