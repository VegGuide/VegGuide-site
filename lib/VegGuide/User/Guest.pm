package VegGuide::User::Guest;

use strict;
use warnings;

use parent 'VegGuide::User';

use VegGuide::Schema;

{
    my $guest_row = VegGuide::Schema->Schema()->User_t()->potential_row(
        values => {
            user_id          => 0,
            email_address    => 'guest@vegguide.org',
            real_name        => 'Guest',
            entries_per_page => 20,
        },
    );

    sub new {
        my $class = shift;

        return bless { row => $guest_row }, $class;
    }
}

sub can_edit_location {0}

sub is_location_owner {0}

sub can_edit_comment {0}

sub can_edit_vendor {0}

sub can_edit_vendor_image {0}

sub can_delete_vendor_image {0}

sub can_edit_user {0}

sub is_guest     {1}
sub is_logged_in {0}

1;
