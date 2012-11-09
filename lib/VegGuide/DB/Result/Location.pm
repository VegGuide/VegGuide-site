use utf8;
package VegGuide::DB::Result::Location;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::Location

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<Location>

=cut

__PACKAGE__->table("Location");

=head1 ACCESSORS

=head2 location_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 200

=head2 localized_name

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 time_zone_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 can_have_vendors

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 is_country

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 parent_location_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 locale_id

  data_type: 'integer'
  is_nullable: 1

=head2 creation_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '2007-01-01 00:00:00'
  is_nullable: 0
  set_on_create: 1
  set_on_update: (empty string)
  timezone: 'local'

=head2 user_id

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 has_addresses

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 has_hours

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=cut

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
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "locale_id",
  { data_type => "integer", is_nullable => 1 },
  "creation_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    default_value             => "2007-01-01 00:00:00",
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => "",
    timezone                  => "local",
  },
  "user_id",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "has_addresses",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "has_hours",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</location_id>

=back

=cut

__PACKAGE__->set_primary_key("location_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:49:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:09A2Ep5yYWyw+KTeC+rSgg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
