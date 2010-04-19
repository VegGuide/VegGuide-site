package VegGuide::Cuisine;

use strict;
use warnings;

use base 'VegGuide::CachedHierarchy';

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema->Cuisine_t );

use VegGuide::Validate qw( validate validate_with SCALAR );

my %CacheParams = (
    parent   => 'parent_cuisine_id',
    id       => 'cuisine_id',
    order_by => 'name',
);

__PACKAGE__->_build_cache( %CacheParams, first => 1 );

sub new {
    my $class = shift;
    my %p     = validate_with(
        params => \@_,
        spec   => {
            cuisine_id => { type => SCALAR, optional => 1 },
        },
        allow_extra => 1,
    );

    if ( $p{cuisine_id} ) {
        my $cuisine = $class->ByID( $p{cuisine_id} );
        return $cuisine if $cuisine;
    }

    return $class->SUPER::new(@_);
}

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

    my $user;
    if ( $p{name} ) {
        my @where;
        push @where, [ $schema->Cuisine_t->name_c, '=', $p{name} ];

        return $schema->Cuisine_t->one_row( where => \@where );
    }

    return;
}

sub create {
    my $self = shift;

    $self->SUPER::create(@_);

    $self->_cached_data_has_changed;
}

sub update {
    my $self = shift;

    $self->SUPER::update(@_);

    $self->_cached_data_has_changed;
}

sub delete {
    my $self = shift;

    $self->SUPER::delete(@_);

    $self->_cached_data_has_changed;
}

sub root_cuisines { $_[0]->_cached_roots }

1;
