package VegGuide::CachedHierarchy;

use strict;
use warnings;
use autodie;

use File::Spec;

use VegGuide::Validate
    qw( validate validate_with SCALAR_TYPE ARRAYREF_TYPE OBJECT ARRAYREF );

# needs to be a global so we can use local()
use vars qw( $Checked );

my %Meta;
my %Cache;
my %Times;

{
    my $spec = {
        parent   => SCALAR_TYPE,
        id       => SCALAR_TYPE,
        order_by => SCALAR_TYPE,
        first    => SCALAR_TYPE( default => 0 ),
    };

    sub _build_cache {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $first = delete $p{first};

        $Cache{$class} = { roots => [] };
        $Meta{$class}{params} = \%p;

        my $clean = $class;
        $clean =~ s/::/-/g;

        my $f = $Meta{$class}{file}
            = File::Spec->catfile( File::Spec->tmpdir, $clean );

        $class->_iterate_all_nodes();

        _touch_file($f) if $first && $ENV{PLACK_ENV};

        $Meta{$class}{last_build} = ( stat $f )[9];

        #    $class->_dump( '_cached_roots', 0 );
    }
}

sub _touch_file {
    my $file = shift;

    open my $fh, '>', $file;

    # The contents don't matter, only the last mod time.
    print $fh "1\n";
    close $fh;

    unless ( $> || $< ) {
        my ( $uid, $gid ) = _get_uid_gid();

        chown $uid, $gid, $file;
    }
}

# XXX - quick hack fix - should revisit at some point
sub _get_uid_gid {
    my $user  = 'www-data';
    my $group = 'www-data';

    my $uid = $user  ? getpwnam($user)  : $>;
    my $gid = $group ? getgrnam($group) : $);

    return ( $uid, $gid );
}

sub _dump {
    my $thing = shift;
    my $meth  = shift;
    my $i     = shift;

    foreach my $n ( $thing->$meth() ) {
        print ' ' x $i;
        print '- ';
        print $n->name;
        print "\n";

        $n->_dump( 'children', $i + 2 );
    }
}

sub _iterate_all_nodes {
    my $class = shift;

    my $all = $class->table()->all_rows();

    while ( my $row = $all->next() ) {
        my $node = $class->new( object => $row );
        $class->_add_node($node);
    }

    $class->_fixup_cache();
}

sub _add_node {
    my $class = shift;
    my $node  = shift;

    delete $node->{__hierarchy_cache__};

    my $parent_col = $Meta{$class}{params}{parent};
    my $id_col     = $Meta{$class}{params}{id};

    my $id_val = $node->$id_col();

    $Cache{$class}{by_id}{$id_val} = $node;

    if ( my $parent = $node->$parent_col() ) {
        $Cache{$class}{nodes}{$id_val}{parent} = $parent;

        push @{ $Cache{$class}{nodes}{$parent}{children} }, $node;
    }
    else {
        push @{ $Cache{$class}{roots} }, $node;
    }
}

sub _fixup_cache {
    my $class = shift;

    my $order_by = $Meta{$class}{params}{order_by};

    $Cache{$class}{roots} = [
        map  { $_->[0] }
        sort { $a->[1] cmp $b->[1] }
        map  { [ $_, $_->$order_by() ] } @{ $Cache{$class}{roots} }
    ];

    for my $id ( keys %{ $Cache{$class}{nodes} } ) {
        $Cache{$class}{nodes}{$id}{parent}
            = $Cache{$class}{by_id}{ $Cache{$class}{nodes}{$id}{parent} }
            if $Cache{$class}{nodes}{$id}{parent};

        $Cache{$class}{nodes}{$id}{children} = [
            map      { $_->[0] }
                sort { $a->[1] cmp $b->[1] }
                map  { [ $_, $_->$order_by() ] }
                @{ $Cache{$class}{nodes}{$id}{children} }
        ];
    }
}

sub _cached_roots {
    my $class = shift;

    $class->_check_cache_time;

    local $Checked = 1;

    return @{ $Cache{$class}{roots} };
}

sub all {
    my $class = shift;

    $class->_check_cache_time;

    local $Checked = 1;

    return map { $_, $_->descendants } @{ $Cache{$class}{roots} };
}
*All = \&all;

sub ByID {
    my $class = shift;
    my $id    = shift;

    $class->_check_cache_time();

    return $Cache{$class}{by_id}{$id};
}

sub parent {
    my $self = shift;

    $self->_check_cache_time;

    local $Checked = 1;

    return $self->{__hierarchy_cache__}{parent}
        if exists $self->{__hierarchy_cache__}{parent};

    return $self->{__hierarchy_cache__}{parent} = $self->_parent();
}

sub _parent {
    my $self  = shift;
    my $class = ref $self;

    my $id_name = $Meta{$class}{params}{id};

    my $id = $self->$id_name();
    return unless defined $id;

    return $Cache{$class}{nodes}{$id}{parent};
}

sub children {
    my $self  = shift;
    my $class = ref $self;

    $self->_check_cache_time;

    local $Checked = 1;

    return @{ $self->{__hierarchy_cache__}{children} }
        if exists $self->{__hierarchy_cache__}{children};

    my $id = $Meta{$class}{params}{id};

    $self->{__hierarchy_cache__}{children}
        = $class->children_of( $self->$id() );

    return @{ $self->{__hierarchy_cache__}{children} };
}

sub children_of {
    my $class  = shift;
    my $id_val = shift;

    return unless defined $id_val;

    return $class->_cached_roots unless defined $id_val;

    return $Cache{$class}{nodes}{$id_val}{children} || [];
}

sub child_count {
    my $self  = shift;
    my $class = ref $self;

    $class->_check_cache_time;

    local $Checked = 1;

    my $id = $Meta{$class}{params}{id};

    # potential rows
    return 0 unless defined $self->$id();

    return 0 unless defined $Cache{$class}{nodes}{ $self->$id() }{children};

    return scalar @{ $Cache{$class}{nodes}{ $self->$id() }{children} };
}

sub ancestors {
    my $self  = shift;
    my $class = ref $self;

    my @a;

    $class->_check_cache_time;

    local $Checked = 1;

    my $node = $self;
    while ( $node = $node->parent ) {
        unshift @a, $node;
    }

    return @a;
}

sub descendants {
    my $self  = shift;
    my $class = ref $self;

    $class->_check_cache_time;

    local $Checked = 1;

    return @{ $self->{__hierarchy_cache__}{descendants} }
        if exists $self->{__hierarchy_cache__}{descendants};

    my @d = $self->children;

    my @c = @d;

    while ( my $node = shift @c ) {
        my @c1 = $node->children;

        push @d, @c1;

        push @c, @c1;
    }

    $self->{__hierarchy_cache__}{descendants} = \@d;

    return @d;
}

sub descendant_ids {
    my $self  = shift;
    my $class = ref $self;

    return @{ $self->{__hierarchy_cache__}{descendant_ids} }
        if exists $self->{__hierarchy_cache__}{descendant_ids};

    my $id = $Meta{$class}{params}{id};

    $self->{__hierarchy_cache__}{descendant_ids}
        = [ map { $_->$id() } $self->descendants ];

    return @{ $self->{__hierarchy_cache__}{descendant_ids} };
}

sub ancestor_ids {
    my $self  = shift;
    my $class = ref $self;

    my $id = $Meta{$class}{params}{id};

    return map { $_->$id() } $self->ancestors;
}

sub _check_cache_time {
    my $class = ref $_[0] || $_[0];

    return if $Checked;

    return unless $ENV{PLACK_ENV};

    my $last_mod = ( stat $Meta{$class}{file} )[9];

    unless ( $last_mod && $last_mod <= $Meta{$class}{last_build} ) {
        $class->_rebuild_cache;
    }
}

sub _rebuild_cache {
    my $class = ref $_[0] || $_[0];

    my %p = %{ $Meta{$class}{params} };

    $class->_build_cache(%p);
}

sub _cached_data_has_changed {
    my $class = ref $_[0] || $_[0];

    $class->_rebuild_cache;

    _touch_file( $Meta{$class}{file} );
}

1;

__END__

