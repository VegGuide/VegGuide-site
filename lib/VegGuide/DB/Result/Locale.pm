use utf8;
package VegGuide::DB::Result::Locale;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::Locale

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

=head1 TABLE: C<Locale>

=cut

__PACKAGE__->table("Locale");

=head1 ACCESSORS

=head2 locale_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 locale_code

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 15

=head2 address_format_id

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 requires_localized_addresses

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "locale_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "locale_code",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 15 },
  "address_format_id",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "requires_localized_addresses",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</locale_id>

=back

=cut

__PACKAGE__->set_primary_key("locale_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zAcu84Qe9s6GvlRwVFFUJg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
