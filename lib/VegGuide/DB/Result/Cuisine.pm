use utf8;
package VegGuide::DB::Result::Cuisine;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("Cuisine");
__PACKAGE__->add_columns(
  "cuisine_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
  "parent_cuisine_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("cuisine_id");
__PACKAGE__->add_unique_constraint("Cuisine___name", ["name"]);
__PACKAGE__->has_many(
  "cuisines",
  "VegGuide::DB::Result::Cuisine",
  { "foreign.parent_cuisine_id" => "self.cuisine_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "parent_cuisine",
  "VegGuide::DB::Result::Cuisine",
  { cuisine_id => "parent_cuisine_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);
__PACKAGE__->has_many(
  "vendor_cuisines",
  "VegGuide::DB::Result::VendorCuisine",
  { "foreign.cuisine_id" => "self.cuisine_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("vendors", "vendor_cuisines", "vendor");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 22:50:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IGoAGQgqBHfeEHaPA34XAw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
