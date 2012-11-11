use utf8;
package VegGuide::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("User");
__PACKAGE__->add_columns(
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "email_address",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 150 },
  "password",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
  "real_name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 100 },
  "home_page",
  { data_type => "varchar", is_nullable => 1, size => 150 },
  "creation_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => 0,
    timezone                  => "local",
  },
  "forgot_password_digest",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "forgot_password_digest_datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
    timezone => "local",
  },
  "is_admin",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "allows_email",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "team_id",
  { data_type => "integer", is_nullable => 1 },
  "entries_per_page",
  { data_type => "integer", default_value => 20, is_nullable => 0 },
  "openid_uri",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "bio",
  { data_type => "mediumtext", is_nullable => 1 },
  "how_veg",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "image_extension",
  { data_type => "varchar", is_nullable => 1, size => 3 },
);
__PACKAGE__->set_primary_key("user_id");
__PACKAGE__->add_unique_constraint("User___email_address", ["email_address"]);
__PACKAGE__->add_unique_constraint("User___openid_uri", ["openid_uri"]);
__PACKAGE__->add_unique_constraint("User___real_name", ["real_name"]);
__PACKAGE__->has_many(
  "created_locations",
  "VegGuide::DB::Result::Location",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "location_comments",
  "VegGuide::DB::Result::LocationComment",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "location_owners",
  "VegGuide::DB::Result::LocationOwner",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_activity_logs",
  "VegGuide::DB::Result::UserActivityLog",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_location_subscriptions",
  "VegGuide::DB::Result::UserLocationSubscription",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_comments",
  "VegGuide::DB::Result::VendorComment",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_images",
  "VegGuide::DB::Result::VendorImage",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_ratings",
  "VegGuide::DB::Result::VendorRating",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendor_suggestions",
  "VegGuide::DB::Result::VendorSuggestion",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendors",
  "VegGuide::DB::Result::Vendor",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("owned_locations", "location_owners", "location");
__PACKAGE__->many_to_many(
  "subscribed_locations",
  "user_location_subscriptions",
  "location",
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 22:50:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5FUIaWMiT1IJnQDYCmjM1w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
