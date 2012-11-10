use utf8;
package VegGuide::DB::Result::LocaleEncoding;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("LocaleEncoding");
__PACKAGE__->add_columns(
  "locale_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "encoding_name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 15 },
);
__PACKAGE__->set_primary_key("locale_id", "encoding_name");
__PACKAGE__->belongs_to(
  "locale",
  "VegGuide::DB::Result::Locale",
  { locale_id => "locale_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 10:41:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8GNf0x+woHJSSHtuLmBKTw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
