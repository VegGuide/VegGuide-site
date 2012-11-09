use utf8;
package VegGuide::DB::Result::Vendor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::Vendor

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

=head1 TABLE: C<Vendor>

=cut

__PACKAGE__->table("Vendor");

=head1 ACCESSORS

=head2 vendor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 100

=head2 localized_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 short_description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 250

=head2 localized_short_description

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 long_description

  data_type: 'text'
  is_nullable: 1

=head2 address1

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 localized_address1

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 address2

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 localized_address2

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 neighborhood

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 localized_neighborhood

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 directions

  data_type: 'mediumtext'
  is_nullable: 1

=head2 city

  data_type: 'varchar'
  is_nullable: 1
  size: 150

=head2 localized_city

  data_type: 'varchar'
  is_nullable: 1
  size: 150

=head2 region

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 localized_region

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 postal_code

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 phone

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 home_page

  data_type: 'varchar'
  is_nullable: 1
  size: 150

=head2 veg_level

  data_type: 'tinyint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

=head2 allows_smoking

  data_type: 'tinyint'
  is_nullable: 1

=head2 is_wheelchair_accessible

  data_type: 'tinyint'
  is_nullable: 1

=head2 accepts_reservations

  data_type: 'tinyint'
  is_nullable: 1

=head2 creation_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0
  set_on_create: 1
  set_on_update: (empty string)
  timezone: 'local'

=head2 last_modified_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0
  set_on_create: 1
  set_on_update: 1
  timezone: 'local'

=head2 last_featured_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1
  timezone: 'local'

=head2 user_id

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 location_id

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 price_range_id

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 localized_long_description

  data_type: 'text'
  is_nullable: 1

=head2 latitude

  data_type: 'float'
  is_nullable: 1

=head2 longitude

  data_type: 'float'
  is_nullable: 1

=head2 is_cash_only

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 close_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1
  timezone: 'local'

=head2 canonical_address

  data_type: 'mediumtext'
  is_nullable: 1

=head2 external_unique_id

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 vendor_source_id

  data_type: 'integer'
  is_nullable: 1

=head2 sortable_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

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
    default_value             => "0000-00-00 00:00:00",
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => "",
    timezone                  => "local",
  },
  "last_modified_datetime",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    default_value             => "0000-00-00 00:00:00",
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
    is_nullable => 0,
  },
  "location_id",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "price_range_id",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
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
  { data_type => "integer", is_nullable => 1 },
  "sortable_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vendor_id>

=back

=cut

__PACKAGE__->set_primary_key("vendor_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<Vendor___external_unique_id___vendor_source_id>

=over 4

=item * L</external_unique_id>

=item * L</vendor_source_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "Vendor___external_unique_id___vendor_source_id",
  ["external_unique_id", "vendor_source_id"],
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:49:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UMwhl/sDJcVjK17yhCzg1Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
