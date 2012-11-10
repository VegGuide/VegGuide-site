use utf8;
package VegGuide::DB::Result::VendorSuggestion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("VendorSuggestion");
__PACKAGE__->add_columns(
  "vendor_suggestion_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "suggestion",
  { data_type => "blob", is_nullable => 0 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "user_wants_notification",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "creation_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => 0,
    timezone                  => "local",
  },
  "vendor_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "user_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("vendor_suggestion_id");
__PACKAGE__->belongs_to(
  "user",
  "VegGuide::DB::Result::User",
  { user_id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "vendor",
  "VegGuide::DB::Result::Vendor",
  { vendor_id => "vendor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wI9UiOROfaNs2abwbp7dig


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
