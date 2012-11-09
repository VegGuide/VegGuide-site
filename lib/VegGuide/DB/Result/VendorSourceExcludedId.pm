use utf8;
package VegGuide::DB::Result::VendorSourceExcludedId;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::VendorSourceExcludedId

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

=head1 TABLE: C<VendorSourceExcludedId>

=cut

__PACKAGE__->table("VendorSourceExcludedId");

=head1 ACCESSORS

=head2 vendor_source_id

  data_type: 'integer'
  is_nullable: 0

=head2 external_unique_id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "vendor_source_id",
  { data_type => "integer", is_nullable => 0 },
  "external_unique_id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vendor_source_id>

=item * L</external_unique_id>

=back

=cut

__PACKAGE__->set_primary_key("vendor_source_id", "external_unique_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qAWo+TFIA9C0AuIQyQqrQA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
