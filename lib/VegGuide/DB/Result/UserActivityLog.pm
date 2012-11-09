use utf8;
package VegGuide::DB::Result::UserActivityLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::UserActivityLog

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

=head1 TABLE: C<UserActivityLog>

=cut

__PACKAGE__->table("UserActivityLog");

=head1 ACCESSORS

=head2 user_activity_log_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 user_activity_log_type_id

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 activity_datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0
  timezone: 'local'

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 vendor_id

  data_type: 'integer'
  is_nullable: 1

=head2 location_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "user_activity_log_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "user_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "user_activity_log_type_id",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "activity_datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
    timezone => "local",
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "vendor_id",
  { data_type => "integer", is_nullable => 1 },
  "location_id",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</user_activity_log_id>

=back

=cut

__PACKAGE__->set_primary_key("user_activity_log_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:93JHFPcDoDGDOxmHaLZRgw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
