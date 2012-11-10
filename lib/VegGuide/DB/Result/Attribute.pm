use utf8;
package VegGuide::DB::Result::Attribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("Attribute");
__PACKAGE__->add_columns(
  "attribute_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("attribute_id");
__PACKAGE__->has_many(
  "_X_vendor_attributes",
  "VegGuide::DB::Result::VendorAttribute",
  { "foreign.attribute_id" => "self.attribute_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("vendors", "_X_vendor_attributes", "vendor");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 11:29:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o/xBxciU/o4asjLOvgSqFA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
