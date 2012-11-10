use utf8;
package VegGuide::DB::Result::UserActivityLogType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("UserActivityLogType");
__PACKAGE__->add_columns(
  "user_activity_log_type_id",
  {
    data_type => "tinyint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 30 },
);
__PACKAGE__->set_primary_key("user_activity_log_type_id");
__PACKAGE__->has_many(
  "user_activity_logs",
  "VegGuide::DB::Result::UserActivityLog",
  {
    "foreign.user_activity_log_type_id" => "self.user_activity_log_type_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yDibczR/8d5LRmyKPLXmhQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
