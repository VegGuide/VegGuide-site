use utf8;
package VegGuide::DB::Result::SurveyResponse2008001;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VegGuide::DB::Result::SurveyResponse2008001

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

=head1 TABLE: C<SurveyResponse2008001>

=cut

__PACKAGE__->table("SurveyResponse2008001");

=head1 ACCESSORS

=head2 survey_response_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 ip_address

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 visit_frequency

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 diet

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 browse_with_purpose

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 browse_for_fun

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 search_by_name

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 search_by_address

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 front_page_new_entries

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 front_page_new_reviews

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 rate_review

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 add_entries

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 just_restaurants

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 listing_filter

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 map_listings

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 printable_listings

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 watch_lists

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 openid

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 vegdining

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 happycow

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 citysearch

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 yelp

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 vegcity

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 other_sites_other

  data_type: 'mediumtext'
  is_nullable: 1

=head2 improvements

  data_type: 'mediumtext'
  is_nullable: 1

=head2 email_address

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "survey_response_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "ip_address",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "visit_frequency",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "diet",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "browse_with_purpose",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "browse_for_fun",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "search_by_name",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "search_by_address",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "front_page_new_entries",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "front_page_new_reviews",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "rate_review",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "add_entries",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "just_restaurants",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "listing_filter",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "map_listings",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "printable_listings",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "watch_lists",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "openid",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "vegdining",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "happycow",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "citysearch",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "yelp",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "vegcity",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "other_sites_other",
  { data_type => "mediumtext", is_nullable => 1 },
  "improvements",
  { data_type => "mediumtext", is_nullable => 1 },
  "email_address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</survey_response_id>

=back

=cut

__PACKAGE__->set_primary_key("survey_response_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-09 14:48:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W1DY3a3j31LnVwyWLBuUdw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
