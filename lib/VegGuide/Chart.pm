package VegGuide::Chart;

use strict;
use warnings;

use Chart::OFC;
use List::Util qw( max );
use Math::Round qw( nhimult );
use VegGuide::User;
use VegGuide::Vendor;


sub GrowthOverTime
{
    my $start = VegGuide::Vendor->EarliestCreationDate();
    $start->truncate( to => 'month' )->add( months => 1 );

    my $today = DateTime->today();

    my @dates;
    for ( my $date = $start; $date < $today; $date->add( months => 1 ) )
    {
        push @dates, $date->clone;
    }

    if ( $today ne $dates[-1] )
    {
        push @dates, $today;
    }

    my @user_count;
    my @vendor_count;

    my @labels;
    for my $d (@dates)
    {
        push @labels, $d->ymd;

        my $u_count =
            VegGuide::User->CountForDateSpan
                    ( start_date => $d->clone()->subtract( months => 1 ),
                      end_date   => $d,
                    );

        push @user_count, ( $user_count[-1] || 0 ) + $u_count;

        my $v_count =
            VegGuide::Vendor->CountForDateSpan
                    ( start_date => $d->clone()->subtract( months => 1 ),
                      end_date   => $d,
                    );

        push @vendor_count, ( $vendor_count[-1] || 0 ) + $v_count;
    }

    my $xaxis =
        Chart::OFC::XAxis->new
                ( axis_label  => 'Date',
                  labels      => \@labels,
                  label_steps => 4,
                  orientation => 'diagonal',
                );

    my $biggest = max @user_count, @vendor_count;

    my $yaxis =
        Chart::OFC::YAxis->new( axis_label  => 'Count',
                                label_steps => 500,
                                max         => nhimult( 500, $biggest + 1 ),
                              );

    my $user_ds =
        Chart::OFC::Dataset::Line->new( values => \@user_count,
                                        label  => 'Users',
                                        color => '#08B000',
                                      );

    my $vendor_ds =
        Chart::OFC::Dataset::Line->new( values => \@vendor_count,
                                        label  => 'Entries',
                                        color => '#0072B0',
                                      );

    my $chart = Chart::OFC::Grid->new( title       => 'Growth over time',
                                       title_style => '{ font-size: 25px; font-weight: bold; color: #9B000A }',
                                       datasets    => [ $user_ds, $vendor_ds ],
                                       x_axis      => $xaxis,
                                       y_axis      => $yaxis,
                                       tool_tip    => '#x_label#<br>#key#: #val#',
                                     );

    return $chart;
}


1;
