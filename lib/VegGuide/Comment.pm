package VegGuide::Comment;

use strict;
use warnings;

use base 'VegGuide::AlzaboWrapper';

use DateTime::Format::MySQL;
use VegGuide::User;


sub user
{
    VegGuide::User->new( object => $_[0]->row_object()->user() );
}

sub last_modified_date
{
    DateTime::Format::MySQL->parse_datetime( $_[0]->last_modified_datetime() )->ymd();
}


1;
