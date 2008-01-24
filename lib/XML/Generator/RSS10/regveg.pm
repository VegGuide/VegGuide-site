package XML::Generator::RSS10::regveg;

use strict;
use warnings;

use base 'XML::Generator::RSS10::Module';

use HTML::Entities qw( encode_entities );
use Params::Validate
    qw( validate SCALAR ARRAYREF );
Params::Validate::validation_options
    ( on_fail => sub { VegGuide::Exception::Params->throw( message => join '', @_ ) } );


sub NamespaceURI { 'http://www.regveg.org/rss/' }


use constant SIMPLE_FIELDS => qw( phone address1 address2
                                  neighborhood directions
                                  city region postal-code country
                                  latitude longitude
                                  home-page
                                  average-rating rating-count
                                  price-range price-range-number
                                  veg-level veg-level-number
                                  allows-smoking
                                  accepts-reservations
                                  is-wheelchair-accessible
                                  is-cash-only
                                  creation-datetime last-modified-datetime
                                  edit-link edit-hours-link
                                  read-reviews-link write-review-link
                                  region-link region-name
                                  image-link image-x image-y
                                  map-link
                                );

use constant SIMPLE_CDATA_FIELDS => qw( long-description );

use constant LIST_FIELDS => ( [ categories        => 'category' ],
                              [ cuisines          => 'cuisine' ],
                              [ 'payment-options' => 'payment-option' ],
                              [ 'features'        => 'feature' ],
                            );

use constant CONTENTS_SPEC => { ( map { $_ => { type => SCALAR, optional => 1 } }
                                  SIMPLE_FIELDS ),
( map { $_ => { type => SCALAR, optional => 1 } }
                                  SIMPLE_CDATA_FIELDS ),
                                ( map { $_->[0] => { type => ARRAYREF, optional => 1 } }
                                  LIST_FIELDS ),
                                hours   => { type => ARRAYREF, optional => 1 },
                              };

sub contents
{
    my $class = shift;
    my $rss   = shift;
    my %p     = validate( @_, CONTENTS_SPEC );

    foreach my $elt (SIMPLE_FIELDS)
    {
        if ( exists $p{$elt} )
        {
            $rss->_element_with_data( $class->Prefix, $elt, $p{$elt} );
            $rss->_newline_if_pretty;
        }
    }

    foreach my $elt (SIMPLE_CDATA_FIELDS)
    {
        if ( exists $p{$elt} )
        {
            $rss->_element_with_cdata( $class->Prefix, $elt, encode_entities( $p{$elt} ) );
            $rss->_newline_if_pretty;
        }
    }

    foreach my $pair (LIST_FIELDS)
    {
        my ( $plural, $singular ) = @$pair;
        if ( $p{$plural} )
        {
            $rss->_start_element( $class->Prefix, $plural );
            $rss->_newline_if_pretty;

            foreach my $v ( @{ $p{$plural} } )
            {
                $rss->_element_with_data( $class->Prefix, $singular, $v );
                $rss->_newline_if_pretty;
            }

            $rss->_end_element( $class->Prefix, $plural );
            $rss->_newline_if_pretty;
        }
    }

    $class->_add_hours( $rss, $p{hours} )
        if $p{hours};
}

sub _add_hours
{
    my $class = shift;
    my $rss   = shift;
    my $hours = shift;

    $rss->_start_element( $class->Prefix, 'hours' );
    $rss->_newline_if_pretty;

    foreach my $day ( 0..6 )
    {
        if ( ! $hours->[$day] )
        {
            $rss->_element( $class->Prefix, 'open-close',
                            [ $class->Prefix, 'day', $day ],
                            [ $class->Prefix, 'unknown', 1 ],
                          );
            $rss->_newline_if_pretty;
            next;
        }

        if ( $hours->[$day][0]{open_minute} == -1 )
        {
            $rss->_element( $class->Prefix, 'open-close',
                            [ $class->Prefix, 'day', $day ],
                            [ $class->Prefix, 'closed', 1 ],
                          );
            $rss->_newline_if_pretty;
            next;
        }

        for my $i ( 0..1 )
        {
            my $set = $hours->[$day][$i];

            next unless $set;

            $rss->_element( $class->Prefix, 'open-close',
                            [ $class->Prefix, 'day', $day ],
                            [ $class->Prefix, 'open',
                              _minutes_as_time( $set->{open_minute} ) ],
                            [ $class->Prefix, 'close',
                              _minutes_as_time( $set->{close_minute} ) ],
                          );
            $rss->_newline_if_pretty;
        }
    }

    $rss->_end_element( $class->Prefix, 'hours' );
    $rss->_newline_if_pretty;
}

sub _minutes_as_time
{
    my $minutes = shift;

    my $hour = int( $minutes / 60 );
    my $min  = $minutes % 60;

    return sprintf( '%02d:%02d', $hour, $min );
}


1;

__END__
