use utf8;
package VegGuide::DB::Result::VendorImage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::VendorImage

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

=head1 TABLE: C<VendorImage>

=cut

__PACKAGE__->table("VendorImage");

=head1 ACCESSORS

=head2 vendor_image_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 vendor_id

  data_type: 'integer'
  is_nullable: 0

=head2 display_order

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 extension

  data_type: 'varchar'
  is_nullable: 0
  size: 3

=head2 caption

  data_type: 'mediumtext'
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "vendor_image_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "vendor_id",
  { data_type => "integer", is_nullable => 0 },
  "display_order",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 0 },
  "extension",
  { data_type => "varchar", is_nullable => 0, size => 3 },
  "caption",
  { data_type => "mediumtext", is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vendor_image_id>

=back

=cut

__PACKAGE__->set_primary_key("vendor_image_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:auaCZ2hWkH9mE2Y4yqbMmA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
