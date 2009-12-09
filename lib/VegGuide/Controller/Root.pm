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

    my $geo = Geo::IP->open( '/usr/share/GeoIP/GeoIPCity.dat', GEOIP_STANDARD );

    # There is a hack here to allow for this to work and show some sort of
    # local data even if the geoip city database is not installed
    my %geo_loc;
    if ($geo)
    {
        my $ip =
              VegGuide::Config->IsProduction()
            ? $c->request()->address()
            : ( $c->request()->params()->{ip} || $c->request()->address() );

        my $record = $geo->record_by_addr($ip);
        %geo_loc =
            map { $_ => $record->$_() }
            qw( city region_name country_code latitude longitude )
                if $record;
    }
    else
    {
        die "It looks like GeoIPCity.dat is not installed\n"
            if VegGuide::Config->IsProduction();

        %geo_loc = ( longitude    => '-93.3063',
                     city         => 'Minneapolis',
                     latitude     => '44.9823',
                     country_code => 'US',
                     region_name  => 'Minnesota'
                   );
    }

    if ( keys %geo_loc )
    {
        my $city = join ', ', uniq( grep { defined } $geo_loc{city}, $geo_loc{region_name} );

        $c->stash()->{city} = $city;

        $c->stash()->{search} =
            VegGuide::Search::Vendor::ByLatLong->new
                ( address      => 'Your location',
                  unit         => ( $geo_loc{country_code} eq 'US' ? 'mile' : 'km' ),
                  latitude     => $geo_loc{latitude},
                  longitude    => $geo_loc{longitude},
                  category_id  => [ VegGuide::Category->Restaurant()->category_id() ],
                  veg_level    => 2,
                  allow_closed => 0,
                );

        $c->stash()->{search}->set_cursor_params( limit => 10, order_by => 'rand' );
    }

    $c->stash()->{news_item} = VegGuide::NewsItem->MostRecent();

    $c->stash()->{template} = '/index';
}

sub recent : Local : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{news_item} = VegGuide::NewsItem->MostRecent();

    $c->stash()->{template} = '/recent';
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
