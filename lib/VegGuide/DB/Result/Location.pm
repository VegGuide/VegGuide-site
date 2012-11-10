use utf8;
package VegGuide::DB::Result::Location;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("Location");
__PACKAGE__->add_columns(
  "location_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 200 },
  "localized_name",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "time_zone_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "can_have_vendors",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "is_country",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "parent_location_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "locale_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "creation_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    default_value             => "2007-01-01 00:00:00",
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => 0,
    timezone                  => "local",
  },
  "user_id",
  {
    data_type => "integer",
    default_value => 1,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "has_addresses",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "has_hours",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("location_id");
__PACKAGE__->has_many(
  "_X_location_owners",
  "VegGuide::DB::Result::LocationOwner",
  { "foreign.location_id" => "self.location_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "_X_user_location_subscriptions",
  "VegGuide::DB::Result::UserLocationSubscription",
  { "foreign.location_id" => "self.location_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "creator",
  "VegGuide::DB::Result::User",
  { user_id => "user_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);
__PACKAGE__->belongs_to(
  "locale",
  "VegGuide::DB::Result::Locale",
  { locale_id => "locale_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);
__PACKAGE__->has_many(
  "location_comments",
  "VegGuide::DB::Result::LocationComment",
  { "foreign.location_id" => "self.location_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "locations",
  "VegGuide::DB::Result::Location",
  { "foreign.parent_location_id" => "self.location_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "parent_location",
  "VegGuide::DB::Result::Location",
  { location_id => "parent_location_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);
__PACKAGE__->has_many(
  "user_activity_logs",
  "VegGuide::DB::Result::UserActivityLog",
  { "foreign.location_id" => "self.location_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "vendors",
  "VegGuide::DB::Result::Vendor",
  { "foreign.location_id" => "self.location_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("owners", "_X_location_owners", "user");
__PACKAGE__->many_to_many("subscribers", "_X_user_location_subscriptions", "user");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 11:30:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:16E6c90782jwWlxA75c1PQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
