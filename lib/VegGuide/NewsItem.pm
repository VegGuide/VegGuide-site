package VegGuide::NewsItem;

use strict;
use warnings;

use DateTime;
use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema()->NewsItem_t() );

use VegGuide::Validate qw( validate SCALAR_TYPE );


{
    my $spec = { limit => SCALAR_TYPE( default => 0 ),
                 start => SCALAR_TYPE( default => 0 ),
               };
    sub All
    {
        my $class = shift;
        my %p     = validate( @_, $spec );

        my %limit;
        if ( $p{limit} )
        {
            $limit{limit} = $p{start} ? [ @p{'limit', 'start'} ] : $p{limit};
        }

        return
            $class->cursor
                ( $class->table()->all_rows
                      ( %limit,
                        order_by => [ $class->table()->creation_datetime_c(), 'DESC' ],
                      )
                );
    }
}

sub Count
{
    my $class = shift;

    return $class->table()->row_count();
}

sub create
{
    my $class = shift;

    return
        $class->SUPER::create
            ( creation_datetime => VegGuide::Schema->Connect()->sqlmaker()->NOW(),
              @_,
            );
}

sub MostRecent
{
    my $class = shift;
    my $days  = shift || 14;

    my $cutoff = DateTime->today()->subtract( days => $days );

    my $row =
        $class->table()->one_row
            ( where =>
              [ $class->table()->creation_datetime_c(), '>=',
                DateTime::Format::MySQL->format_datetime($cutoff) ],
              order_by => [ $class->table()->creation_datetime_c(), 'DESC' ],
            );

    return $class->new( object => $row ) if $row;
}

sub MostRecentItems
{
    my $class = shift;
    my %p     = @_;

    my $cutoff = DateTime->today()->subtract( days => $p{days} || 14 );

    return $class->cursor
        ( $class->table()->rows_where
              ( where =>
                [ $class->table()->creation_datetime_c(), '>=',
                  DateTime::Format::MySQL->format_datetime($cutoff) ],
                order_by => [ $class->table()->creation_datetime_c(), 'DESC' ],
                limit => ( $p{limit} || 5 ),
              )
        );
}


1;
