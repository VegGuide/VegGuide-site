package VegGuide::Team;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema->Team_t );

use VegGuide::Exceptions ( subs => ['data_validation_error'] );
use VegGuide::Util;

use VegGuide::Validate qw( validate SCALAR );

sub _new_row {
    my $class = shift;
    my %p     = validate_with(
        params => \@_,
        spec   => {
            name => { type => SCALAR, optional => 1 },
        },
        allow_extra => 1,
    );

    my $schema = VegGuide::Schema->Connect();

    my @where;
    if ( exists $p{name} ) {
        push @where, [ $schema->Team_t->name_c, '=', $p{name} ];
    }

    return $schema->Team_t->one_row( where => \@where );
}

sub create {
    my $class = shift;

    my $team = $class->SUPER::create(@_);

    my $owner = $team->owner;

    $owner->update( team_id => $team->team_id )
        unless $owner->team_id;

    return $team;
}

sub _validate_data {
    my $self = shift;
    my $data = shift;

    my @errors;
    for my $f ( name description ) {
        push @errors, ucfirst $f . ' is required.'
            unless grep { defined && length } $data->{$f};
    }

    data_validation_error error => "One or more data validation errors",
        errors                  => \@errors
        if @errors;

    $data->{home_page} = VegGuide::Util::normalize_uri( $data->{home_page} )
        if defined $data->{home_page};
}

sub owner { VegGuide::User->new( user_id => $_[0]->owner_user_id ) }

sub member_count {
    my $self = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->User_t->row_count(
        where => [ $schema->User_t->team_id_c, '=', $self->team_id ],
    );
}

sub All {
    my $class = shift;

    return $class->cursor(
        $class->table->all_rows( order_by => $class->table->name_c ) );
}

1;
