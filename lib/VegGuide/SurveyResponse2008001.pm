package VegGuide::SurveyResponse2008001;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema()->SurveyResponse2008001_t() );

sub VisitFrequencies {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my %freq;
    for my $row (
        $class->table()->function(
            select => [
                $class->table()->visit_frequency_c(),
                $schema->sqlmaker()->COUNT('*'),
            ],
            group_by => $class->table()->visit_frequency_c(),
        )
        ) {
        $freq{ $row->[0] } = $row->[1];
    }

    return \%freq;
}

sub Diets {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my %freq;
    for my $row (
        $class->table()->function(
            select => [
                $class->table()->diet_c(),
                $schema->sqlmaker()->COUNT('*'),
            ],
            group_by => $class->table()->diet_c(),
        )
        ) {
        $freq{ $row->[0] } = $row->[1];
    }

    return \%freq;
}

sub Activities {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my @cols = qw( browse_with_purpose
        browse_for_fun
        search_by_name
        search_by_address
        front_page_new_entries
        front_page_new_reviews
        rate_review
        add_entries
    );
    my ($row) = $class->table()->function(
        select => [
            map { $schema->sqlmaker()->SUM($_) }
                $class->table()->columns(@cols)
        ],
    );

    my %activities;
    @activities{@cols} = @{$row};

    return \%activities;
}

sub Features {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my @cols = qw( just_restaurants
        listing_filter
        map_listings
        printable_listings
        watch_lists
        openid
    );
    my ($row) = $class->table()->function(
        select => [
            map { $schema->sqlmaker()->SUM($_) }
                $class->table()->columns(@cols)
        ],
    );

    my %activities;
    @activities{@cols} = @{$row};

    return \%activities;
}

sub OtherSites {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my @cols = qw( vegdining
        happycow
        citysearch
        yelp
        vegcity
    );
    my ($row) = $class->table()->function(
        select => [
            map { $schema->sqlmaker()->SUM($_) }
                $class->table()->columns(@cols)
        ],
    );

    my %activities;
    @activities{@cols} = @{$row};

    return \%activities;
}

sub OtherSitesOther {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    return $class->table()->function(
        select => $class->table()->column('other_sites_other'),
        where =>
            [ $class->table()->column('other_sites_other'), '!=', undef ],
    );
}

sub Improvements {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my $handle = $class->table()->select(
        select =>
            [ $class->table()->columns( 'email_address', 'improvements' ) ],
        where => [ $class->table()->column('improvements'), '!=', undef ],
    );

    return [ $handle->all_rows_hash() ];
}

1;
