package VegGuide::Controller::Root;

use strict;
use warnings;

use base 'VegGuide::Controller::Base';

use Geo::IP;
use List::AllUtils qw( uniq );
use VegGuide::Category;
use VegGuide::Config;
use VegGuide::Search::Vendor::ByLatLong;
use VegGuide::SiteURI qw( region_uri );
use VegGuide::Util qw( string_is_empty );
use VegGuide::Vendor;

__PACKAGE__->config()->{namespace} = '';


sub index : Path('/') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{is_front_page} = 1;

    my $geo = Geo::IP->open( '/usr/share/GeoIP/GeoIPCity.dat', GEOIP_STANDARD );

    my $ip =
          ! VegGuide::Config->IsProduction()
        ? ( $c->request()->params()->{ip} || $c->request()->address() )
        : $c->request()->address();

    my $loc = $geo->record_by_addr($ip);

    if ($loc)
    {
        my $city = join ', ', uniq( grep { defined } $loc->city(), $loc->region_name() );

        $c->stash()->{city} = $city;

        $c->stash()->{search} =
            VegGuide::Search::Vendor::ByLatLong->new
                ( address     => 'Your location',
                  unit        => ( $loc->country_code() eq 'US' ? 'mile' : 'km' ),
                  latitude    => $loc->latitude(),
                  longitude   => $loc->longitude(),
                  category_id => [ VegGuide::Category->Restaurant()->category_id() ],
            );

        $c->stash()->{search}->set_cursor_params( limit => 4 );
    }

    $c->stash()->{news_item} = VegGuide::NewsItem->MostRecent();

    $c->stash()->{template} = '/index';
}

# Used to exit gracefully for the benefit of profilers like FastProf
sub exit : Path('/exit') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    VegGuide::Exception->throw( 'Naughty attempt to kill VegGuide server' )
        if VegGuide::Config->IsProduction();

    exit 0;
}

sub warn : Path('/warn') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    warn "A warning in the logs\n";

    $c->detach('index');
}

# This should only be callable in a dev environment
sub robots_txt : Path('/robots.txt') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->response()->content_type('text/plain');
    $c->response()->body("User-agent: *\nDisallow: /\n");
}

sub home : Path('/home')
{
    my $self = shift;
    my $c    = shift;

    my $location = $c->skin()->home_location();

    my $redirect = $location ? region_uri( location => $location ) : '/';

    $c->redirect_and_detach($redirect);
}

{
    my @Days = @{ DateTime::Locale->load('en_US')->day_names() };
    sub hours_descriptions : Path('/hours-descriptions')
    {
        my $self = shift;
        my $c    = shift;

        my @descs;
        for my $d ( 0..6 )
        {
            my $is_closed = $c->request()->param("is-closed-$d");
            my $hours0    = $c->request()->param("hours-$d-0");

            if ($is_closed)
            {
                $descs[$d]{s0} = 'closed';
                next;
            }

            next if string_is_empty($hours0);

            if ( $hours0 =~ /^\s* s/xism )
            {
                if ($d)
                {
                    $descs[$d] = $descs[ $d - 1 ];
                }
                else
                {
                    $descs[$d]{s0} = 'same as what?';
                }
                next;
            }

            if ( $hours0 eq 'closed' )
            {
                $descs[$d]{s0} = '';
                next;
            }

            $descs[$d]{s0} = eval { VegGuide::Vendor->CanonicalHoursRangeDescription($hours0) };

            if ( my $e = Exception::Class->caught('VegGuide::Exception::DataValidation') )
            {
                $descs[$d]{error} = $e->error();
            }

            my $hours1 = $c->request()->param("hours-$d-1");

            if ( ! string_is_empty($hours1) )
            {
                $descs[$d]{s1} =
                    eval { VegGuide::Vendor->CanonicalHoursRangeDescription( $hours1, 'assume pm' ) };

                if ( my $e = Exception::Class->caught('VegGuide::Exception::DataValidation') )
                {
                    $descs[$d]{error} = $e->error();
                }
            }
        }

        $self->status_ok( $c,
                          entity => \@descs,
                        );
    }
}

sub test500 : Local
{
    die "Test 500";
}


1;

__END__

=head1 NAME

VegGuide::Controller::Root - Catalyst Controller

=head1 SYNOPSIS

See L<VegGuide>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 default


=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
