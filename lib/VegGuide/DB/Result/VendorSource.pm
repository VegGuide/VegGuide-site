use utf8;
package VegGuide::DB::Result::VendorSource;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("VendorSource");
__PACKAGE__->add_columns(
  "vendor_source_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "display_uri",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "feed_uri",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "filter_class",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "last_processed_datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
    timezone => "local",
  },
);
__PACKAGE__->set_primary_key("vendor_source_id");
__PACKAGE__->add_unique_constraint("VendorSource___feed_uri", ["feed_uri"]);
__PACKAGE__->has_many(
  "vendor_source_excluded_ids",
  "VegGuide::DB::Result::VendorSourceExcludedId",
  { "foreign.vendor_source_id" => "self.vendor_source_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendors",
  "VegGuide::DB::Result::Vendor",
  { "foreign.vendor_source_id" => "self.vendor_source_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+/miqIO8Zs4/wqAjsDM9Ng


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
