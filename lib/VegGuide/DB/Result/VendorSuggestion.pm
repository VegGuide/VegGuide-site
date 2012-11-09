use utf8;
package VegGuide::DB::Result::VendorSuggestion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::VendorSuggestion

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

=head1 TABLE: C<VendorSuggestion>

=cut

__PACKAGE__->table("VendorSuggestion");

=head1 ACCESSORS

=head2 vendor_suggestion_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 suggestion

  data_type: 'blob'
  is_nullable: 0

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 user_wants_notification

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 creation_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0
  set_on_create: 1
  set_on_update: (empty string)
  timezone: 'local'

=head2 vendor_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "vendor_suggestion_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "suggestion",
  { data_type => "blob", is_nullable => 0 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "user_wants_notification",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
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
  "vendor_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "user_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vendor_suggestion_id>

=back

=cut

__PACKAGE__->set_primary_key("vendor_suggestion_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:49:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AC3ljQcjBlocb7dYmBD2+A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
