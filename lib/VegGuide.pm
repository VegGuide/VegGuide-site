package VegGuide;

use strict;
use warnings;

our $VERSION = '0.01';

our $REST_VERSION = '0.0.6';

use Catalyst;
use DateTime;
use VegGuide::Client;
use VegGuide::Config;
use VegGuide::Request;
use VegGuide::Response;

use VegGuide::Engine;

use VegGuide::Attribute;
use VegGuide::Comment;
use VegGuide::Cuisine;
use VegGuide::Location;
use VegGuide::User;
use VegGuide::Vendor;
use VegGuide::VendorSource;

use namespace::autoclean;
use Moose;

BEGIN {
    extends 'Catalyst';

    Catalyst->import( VegGuide::Config->CatalystImports() );
}

with( VegGuide::Config->CatalystRoles() );

__PACKAGE__->config(
    name => 'VegGuide',
    VegGuide::Config->CatalystConfig(),
);

__PACKAGE__->request_class('VegGuide::Request');
__PACKAGE__->response_class('VegGuide::Response');

__PACKAGE__->setup();

sub client {
    my $self = shift;

    my $stash = $self->stash();

    return $stash->{client} if $stash->{client};

    my $location = $stash->{location};
    $location ||= $stash->{vendor}->location()
        if $stash->{vendor};

    my $locale;
    $locale = $location->locale() if $location;

    return $stash->{client} = VegGuide::Client->new(
        $self->request(),
        $locale,
        $self->vg_user()->is_admin(),
    );
}

{

    package Devel::InnerPackage;

    no warnings 'redefine';

    sub list_packages {
        my $pack = shift;
        $pack .= "::" unless $pack =~ m!::$!;

        no strict 'refs';
        my @packs;
        my @stuff = grep !/^(main|)::$/, keys %{$pack};

        # This is a monkey-patch for some weirdness where D::IP ends
        # up thinking VegGuide::View::Mason has an inner package of
        # VegGuide::View::Mason::SUPER. This only happens when the
        # full Catalyst stack is also loaded.
        for my $cand ( grep { !/SUPER::$/ } grep /::$/, @stuff ) {
            $cand =~ s!::$!!;
            my @children = list_packages( $pack . $cand );

            push @packs, "$pack$cand"
                unless $cand =~ /^::/
                    || !__PACKAGE__->_loaded( $pack . $cand ); # or @children;
            push @packs, @children;
        }
        return grep { $_ !~ /::::ISA::CACHE/ } @packs;
    }

}

1;

__END__

=head1 NAME

VegGuide - Catalyst based application

=head1 SYNOPSIS

    script/vegguide_server.pl

=head1 DESCRIPTION

Catalyst based application.

=head1 METHODS

=head2 default

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
