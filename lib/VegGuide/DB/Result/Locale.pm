use utf8;
package VegGuide::DB::Result::Locale;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->table("Locale");
__PACKAGE__->add_columns(
  "locale_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "locale_code",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 15 },
  "address_format_id",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "requires_localized_addresses",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("locale_id");
__PACKAGE__->belongs_to(
  "address_format",
  "VegGuide::DB::Result::AddressFormat",
  { address_format_id => "address_format_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);
__PACKAGE__->has_many(
  "locales_encoding",
  "VegGuide::DB::Result::LocaleEncoding",
  { "foreign.locale_id" => "self.locale_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "locations",
  "VegGuide::DB::Result::Location",
  { "foreign.locale_id" => "self.locale_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-10 22:50:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:edWfXolVWg8eYYA8aQqCtw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
