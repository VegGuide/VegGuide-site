use utf8;
package VegGuide::DB::Result::Skin;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::Skin

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

=head1 TABLE: C<Skin>

=cut

__PACKAGE__->table("Skin");

=head1 ACCESSORS

=head2 skin_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 hostname

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

=head2 tagline

  data_type: 'mediumtext'
  is_nullable: 1

=head2 owner_user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 home_location_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "skin_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "hostname",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
  "tagline",
  { data_type => "mediumtext", is_nullable => 1 },
  "owner_user_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "home_location_id",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</skin_id>

=back

=cut

__PACKAGE__->set_primary_key("skin_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HDXseYBjIhQoXv11eQ1Esg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
