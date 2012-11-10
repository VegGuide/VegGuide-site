use utf8;
package VegGuide::DB::Result::VendorHour;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("VendorHours");
__PACKAGE__->add_columns(
  "vendor_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "day",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "open_minute",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "close_minute",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("vendor_id", "day", "open_minute", "close_minute");
__PACKAGE__->belongs_to(
  "vendor",
  "VegGuide::DB::Result::Vendor",
  { vendor_id => "vendor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uWZrQuyjQasPtVxIszAqkw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
