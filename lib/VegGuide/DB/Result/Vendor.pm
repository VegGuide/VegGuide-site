use utf8;
package VegGuide::DB::Result::Vendor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("Vendor");
__PACKAGE__->add_columns(
  "vendor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 100 },
  "localized_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "short_description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 250 },
  "localized_short_description",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "long_description",
  { data_type => "text", is_nullable => 1 },
  "address1",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "localized_address1",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "address2",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "localized_address2",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "neighborhood",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "localized_neighborhood",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "directions",
  { data_type => "mediumtext", is_nullable => 1 },
  "city",
  { data_type => "varchar", is_nullable => 1, size => 150 },
  "localized_city",
  { data_type => "varchar", is_nullable => 1, size => 150 },
  "region",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "localized_region",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "postal_code",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "home_page",
  { data_type => "varchar", is_nullable => 1, size => 150 },
  "veg_level",
  {
    data_type => "tinyint",
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "allows_smoking",
  { data_type => "tinyint", is_nullable => 1 },
  "is_wheelchair_accessible",
  { data_type => "tinyint", is_nullable => 1 },
  "accepts_reservations",
  { data_type => "tinyint", is_nullable => 1 },
  "creation_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => 0,
    timezone                  => "local",
  },
  "last_modified_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => 1,
    timezone                  => "local",
  },
  "last_featured_date",
  {
    data_type => "date",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
    timezone => "local",
  },
  "user_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "location_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "price_range_id",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "localized_long_description",
  { data_type => "text", is_nullable => 1 },
  "latitude",
  { data_type => "float", is_nullable => 1 },
  "longitude",
  { data_type => "float", is_nullable => 1 },
  "is_cash_only",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "close_date",
  {
    data_type => "date",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
    timezone => "local",
  },
  "canonical_address",
  { data_type => "mediumtext", is_nullable => 1 },
  "external_unique_id",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "vendor_source_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "sortable_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("vendor_id");
__PACKAGE__->add_unique_constraint(
  "Vendor___external_unique_id___vendor_source_id",
  ["external_unique_id", "vendor_source_id"],
);
__PACKAGE__->belongs_to(
  "location",
  "VegGuide::DB::Result::Location",
  { location_id => "location_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "price_range",
  "VegGuide::DB::Result::PriceRange",
  { price_range_id => "price_range_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "user",
  "VegGuide::DB::Result::User",
  { user_id => "user_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);
__PACKAGE__->has_many(
  "user_activity_logs",
  "VegGuide::DB::Result::UserActivityLog",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_attributes",
  "VegGuide::DB::Result::VendorAttribute",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_categories",
  "VegGuide::DB::Result::VendorCategory",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_comments",
  "VegGuide::DB::Result::VendorComment",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_cuisines",
  "VegGuide::DB::Result::VendorCuisine",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_hours",
  "VegGuide::DB::Result::VendorHour",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_images",
  "VegGuide::DB::Result::VendorImage",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_payment_options",
  "VegGuide::DB::Result::VendorPaymentOption",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_ratings",
  "VegGuide::DB::Result::VendorRating",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "vendor_source",
  "VegGuide::DB::Result::VendorSource",
  { vendor_source_id => "vendor_source_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);
__PACKAGE__->has_many(
  "vendor_suggestions",
  "VegGuide::DB::Result::VendorSuggestion",
  { "foreign.vendor_id" => "self.vendor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("attributes", "vendor_attributes", "attribute");
__PACKAGE__->many_to_many("categories", "vendor_categories", "category");
__PACKAGE__->many_to_many("cuisines", "vendor_cuisines", "cuisine");
__PACKAGE__->many_to_many("payment_options", "vendor_payment_options", "payment_option");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 22:50:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bk1bg5oa+PgXr/5D3o/ExQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
