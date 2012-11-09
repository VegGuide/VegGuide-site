use utf8;
package VegGuide::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::User

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

=head1 TABLE: C<User>

=cut

__PACKAGE__->table("User");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 email_address

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 150

=head2 password

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 40

=head2 real_name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 100

=head2 home_page

  data_type: 'varchar'
  is_nullable: 1
  size: 150

=head2 creation_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0
  set_on_create: 1
  set_on_update: (empty string)
  timezone: 'local'

=head2 forgot_password_digest

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 forgot_password_digest_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1
  timezone: 'local'

=head2 is_admin

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 allows_email

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 team_id

  data_type: 'integer'
  is_nullable: 1

=head2 entries_per_page

  data_type: 'integer'
  default_value: 20
  is_nullable: 0

=head2 openid_uri

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 bio

  data_type: 'mediumtext'
  is_nullable: 1

=head2 how_veg

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 image_extension

  data_type: 'varchar'
  is_nullable: 1
  size: 3

=cut

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
    default_value             => "0000-00-00 00:00:00",
    is_nullable               => 0,
    set_on_create             => 1,
    set_on_update             => "",
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

=head1 PRIMARY KEY

=over 4

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("user_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<User___email_address>

=over 4

=item * L</email_address>

=back

=cut

__PACKAGE__->add_unique_constraint("User___email_address", ["email_address"]);

=head2 C<User___openid_uri>

=over 4

=item * L</openid_uri>

=back

=cut

__PACKAGE__->add_unique_constraint("User___openid_uri", ["openid_uri"]);

=head2 C<User___real_name>

=over 4

=item * L</real_name>

=back

=cut

__PACKAGE__->add_unique_constraint("User___real_name", ["real_name"]);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:49:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mhUb8XS7VJiCFT3XvfKLVA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
