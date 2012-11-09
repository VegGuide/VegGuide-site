use utf8;
package VegGuide::DB::Result::Team;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::Team

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

=head1 TABLE: C<Team>

=cut

__PACKAGE__->table("Team");

=head1 ACCESSORS

=head2 team_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 250

=head2 description

  data_type: 'text'
  is_nullable: 0

=head2 home_page

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 owner_user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "team_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 250 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "home_page",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "owner_user_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</team_id>

=back

=cut

__PACKAGE__->set_primary_key("team_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<Team___name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("Team___name", ["name"]);

=head2 C<Team___owner_user_id>

=over 4

=item * L</owner_user_id>

=back

=cut

__PACKAGE__->add_unique_constraint("Team___owner_user_id", ["owner_user_id"]);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LrJt+C4EK98PYj0dvpbJWA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
