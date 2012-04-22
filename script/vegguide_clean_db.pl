#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";

use VegGuide::User;

my %skip = map { $_ => 1 } qw( dave@ca4a.org autarch@urth.org );

my $users = VegGuide::User->All();

while ( my $user = $users->next() ) {
    my $address
        = $skip{ $user->email_address() }
        ? $user->email_address()
        : 'sanitized-' . $user->user_id() . '@example.com';

    $user->update(
        email_address          => $address,
        password               => 'password',
        password2              => 'password',
        forgot_password_digest => undef,
        openid_uri             => undef,
    );
}

my $dbh = VegGuide::Schema->Connect()->driver()->handle();
$dbh->do(
    'UPDATE SurveyResponse2008001 SET email_address = ?',
    undef,
    'sanitized@example.com'
);
