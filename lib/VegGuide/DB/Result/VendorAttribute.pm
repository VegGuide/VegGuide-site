use utf8;
package VegGuide::DB::Result::VendorAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::VendorAttribute

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

=head1 TABLE: C<VendorAttribute>

=cut

__PACKAGE__->table("VendorAttribute");

=head1 ACCESSORS

=head2 vendor_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 attribute_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "vendor_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "attribute_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vendor_id>

=item * L</attribute_id>

=back

=cut

__PACKAGE__->set_primary_key("vendor_id", "attribute_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R9aH4MEn9CmB+OqltT7jdQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
