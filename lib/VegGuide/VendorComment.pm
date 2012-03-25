package VegGuide::VendorComment;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper (
    table => VegGuide::Schema->Schema->VendorComment_t );

use parent 'VegGuide::Comment';

use Class::Trait qw( VegGuide::Role::FeedEntry );

use VegGuide::SiteURI qw( entry_review_uri );

use VegGuide::Validate qw( validate SCALAR );

sub vendor {
    my $self = shift;

    return $self->{vendor}
        ||= VegGuide::Vendor->new( object => $self->row_object()->vendor() );
}

sub location { $_[0]->vendor->location }

sub rating {
    my $self = shift;

    return if $self->row_object()->is_potential();

    return $self->vendor()->rating_from_user( $self->user() );
}

# provided for FeedEntry
sub creation_datetime_object {
    return $_[0]->last_modified_datetime_object();
}

sub feed_title {
    my $self = shift;

    my $title = 'Review of ' . $self->vendor()->name();
    $title .= ' in ' . $self->location->name_with_parent;
    $title .= ' by ' . $self->user()->real_name();

    return $title;
}

sub feed_uri {
    my $self = shift;

    return entry_review_uri(
        vendor    => $self->vendor(),
        user      => $self->user(),
        with_host => 1,
    );
}

sub feed_template_params {
    my $self = shift;

    return ( '/vendor-comment-content.mas', comment => $self );
}

sub delete {
    my $self = shift;
    my %p    = validate(
        @_, {
            calling_user => { isa => 'VegGuide::User' },
        },
    );

    $self->user->insert_activity_log(
        type      => 'delete review',
        vendor_id => $self->vendor_id,
        comment   => 'Deleted by ' . $p{calling_user}->real_name,
    );

    $self->SUPER::delete;
}

sub All {
    my $class = shift;
    my %p     = validate(
        @_, {
            order_by   => { default  => 'name' },
            sort_order => { default  => 'ASC' },
            limit      => { optional => 1 },
            start      => { default  => 0 },
        },
    );

    my $schema = VegGuide::Schema->Connect();

    my @order_by;
    if ( lc $p{order_by} eq 'modified' ) {
        @order_by = (
            $schema->VendorComment_t()->last_modified_datetime_c(),
            'DESC',
            $schema->User_t()->real_name_c(),
            'ASC',
        );
    }
    else {
        @order_by = (
            $schema->User_t()->real_name_c(),
            'ASC',
        );
    }

    my %limit;
    %limit = ( limit => [ $p{limit}, $p{start} ] )
        if $p{limit};

    return $class->cursor(
        $schema->join(
            select =>
                [ $schema->tables( 'VendorComment', 'Vendor', 'User' ) ],
            join => [
                [ $schema->tables( 'VendorComment', 'Vendor' ) ],
                [ $schema->tables( 'VendorComment', 'User' ) ],
            ],
            order_by => \@order_by,
            %limit,
        )
    );
}

sub NewCommentCount {
    my $class = shift;
    my %p     = validate(
        @_, {
            days => { type => SCALAR },
        },
    );

    my $week_ago = DateTime->today()->subtract( days => 7 );

    my $schema = VegGuide::Schema->Connect();

    my @where = (
        $schema->VendorComment_t()->last_modified_datetime_c(),
        '>=',
        DateTime::Format::MySQL->format_datetime($week_ago)
    );

    return $schema->VendorComment_t()->function(
        select =>
            $schema->sqlmaker->COUNT( $schema->VendorComment_t->vendor_id_c ),
        where => \@where,
    );
}

sub Count {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    return $schema->VendorComment_t()
        ->function( select =>
            $schema->sqlmaker->COUNT( $schema->VendorComment_t->vendor_id_c )
        );
}

1;
