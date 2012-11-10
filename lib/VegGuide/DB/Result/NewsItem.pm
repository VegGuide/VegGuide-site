use utf8;
package VegGuide::DB::Result::NewsItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("NewsItem");
__PACKAGE__->add_columns(
  "item_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 250 },
  "creation_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => 0,
    timezone                  => "local",
  },
  "body",
  { data_type => "mediumtext", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("item_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MGSuerWNMNC7Mtl5tZFczQ

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
