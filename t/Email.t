use strict;
use warnings;

use Test::More;

use VegGuide::Email;

VegGuide::Email->TestMode();

{
    Email::Send::Test->clear();
    VegGuide::Email->Send(
        to       => 'to@example.com',
        from     => 'from@example.com',
        subject  => 'Testing',
        template => 'forgot-password',
        params   => { uri => 'http://example.com' },
    );

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent' );

    my $email = $emails[0];
    is(
        $email->header('To'), 'to@example.com',
        'check To address'
    );
    is(
        $email->header('From'), 'from@example.com',
        'check From address'
    );
    is(
        $email->header('Reply-To'), q|"VegGuide.Org" <guide@vegguide.org>|,
        'check Reply-To address'
    );
    is(
        $email->header('Subject'), 'Testing',
        'check Subject'
    );
    is(
        $email->header('Content-Transfer-Encoding'), '8bit',
        'check Content-Transfer-Encoding'
    );
    is(
        $email->header('X-Sender'), 'VegGuide::Email',
        'check X-Sender'
    );
    like(
        $email->content_type(), qr{multipart/alternative},
        'check Content-Type'
    );
    ok( $email->header('Message-ID'), 'header has Message-ID' );
    ok( $email->header('Date'),       'header has Date' );
}

done_testing();
