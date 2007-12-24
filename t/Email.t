use strict;
use warnings;

use Test::More tests => 14;

use VegGuide::Email;


VegGuide::Email->TestMode();

{
    Email::Send::Test->clear();
    VegGuide::Email->Send( to      => 'to@example.com',
                           from    => 'from@example.com',
                           subject => 'Testing',
                           body    => 'Test',
                         );

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent' );

    my $email = $emails[0];
    is( $email->header('To'), 'to@example.com',
        'check To address' );
    is( $email->header('From'), 'from@example.com',
        'check From address' );
    is( $email->header('Reply-To'), q|"VegGuide.Org" <guide@vegguide.org>|,
        'check Reply-To address' );
    is( $email->header('Subject'), 'Testing',
        'check Subject' );
    is( $email->header('Content-Transfer-Encoding'), '8bit',
        'check Content-Transfer-Encoding' );
    is( $email->header('X-Sender'), 'VegGuide::Email',
        'check X-Sender' );
    is( $email->content_type(), q|text/plain; charset="UTF-8"|,
        'check Content-Type' );
    is( $email->header('Content-Disposition'), 'inline',
        'check Content-Disposition' );
    ok( $email->header('Message-ID'), 'header has Message-ID');
    ok( $email->header('Date'), 'header has Date');
    is( $email->body(), 'Test', 'check body' );
}

{
    Email::Send::Test->clear();

    my $body = '12345679 ' x 20;
    VegGuide::Email->Send( to      => 'to@example.com',
                           from    => 'from@example.com',
                           subject => 'Testing',
                           body    => $body,
                         );

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent' );

    my $sent_body = $emails[0]->body();
    my $max_length = 0;
    for my $line ( split /\n/, $sent_body )
    {
        $max_length = length $line
            if length $line > $max_length;
    }

    ok( $max_length <= 72, 'no line in body is longer than 72 characters' );
}
