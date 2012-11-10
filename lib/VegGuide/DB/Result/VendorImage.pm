use utf8;
package VegGuide::DB::Result::VendorImage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("VendorImage");
__PACKAGE__->add_columns(
  "vendor_image_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "vendor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "display_order",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 0 },
  "extension",
  { data_type => "varchar", is_nullable => 0, size => 3 },
  "caption",
  { data_type => "mediumtext", is_nullable => 1 },
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("vendor_image_id");
__PACKAGE__->belongs_to(
  "user",
  "VegGuide::DB::Result::User",
  { user_id => "user_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "vendor",
  "VegGuide::DB::Result::Vendor",
  { vendor_id => "vendor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6k+agPTkY5624Ga9WMd5Vw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
