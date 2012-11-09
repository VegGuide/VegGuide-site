use utf8;
package VegGuide::DB::Result::PaymentOption;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::PaymentOption

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

=head1 TABLE: C<PaymentOption>

=cut

__PACKAGE__->table("PaymentOption");

=head1 ACCESSORS

=head2 payment_option_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

=cut

__PACKAGE__->add_columns(
  "payment_option_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
);

=head1 PRIMARY KEY

=over 4

=item * L</payment_option_id>

=back

=cut

__PACKAGE__->set_primary_key("payment_option_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E4HwzojMKYgjzcWf7sRWyA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
