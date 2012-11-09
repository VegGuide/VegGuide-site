use utf8;
package VegGuide::DB::Result::VendorComment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::VendorComment

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

=head1 TABLE: C<VendorComment>

=cut

__PACKAGE__->table("VendorComment");

=head1 ACCESSORS

=head2 vendor_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 last_modified_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0
  set_on_create: 1
  set_on_update: 1
  timezone: 'local'

=cut

__PACKAGE__->add_columns(
  "vendor_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "user_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "comment",
  { data_type => "text", is_nullable => 1 },
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
);

=head1 PRIMARY KEY

=over 4

=item * L</vendor_id>

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("vendor_id", "user_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:49:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:T+YGEdOHUxcpuuS53IZhxw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
