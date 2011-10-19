package VegGuide;

use strict;
use warnings;

our $VERSION = '0.01';

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
use VegGuide::Skin;
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

{

    # monkey patch to fix Catalyst::Runtime issue
    use Moose::Util qw/find_meta/;

    sub setup_engine {
        my ( $class, $requested_engine ) = @_;

        my $engine = $class->engine_class($requested_engine);

        # Don't really setup_engine -- see _setup_psgi_app for explanation.
        return if $class->loading_psgi_file;

        Class::MOP::load_class($engine);

        if ( $ENV{MOD_PERL} ) {
            my $apache = $class->engine_loader->auto;

            my $meta              = find_meta($class);
            my $was_immutable     = $meta->is_immutable;
            my %immutable_options = $meta->immutable_options;
            $meta->make_mutable if $was_immutable;

            $meta->add_method(
                handler => sub {
                    my $r        = shift;
                    my $psgi_app = $class->_finalized_psgi_app;
                    $apache->call_app( $r, $psgi_app );
                }
            );

            $meta->make_immutable(%immutable_options) if $was_immutable;
        }

        $class->engine( $engine->new );

        return;
    }
}

sub skin {
    my $self = shift;

    return $self->{skin}
        if $self->{skin};

    if ( $self->request()->param('skin_id') ) {
        return $self->{skin} = VegGuide::Skin->new(
            skin_id => $self->request()->param('skin_id') );
    }

    return $self->{skin} = VegGuide::Skin->SkinForHostname(
        ( $self->request()->uri()->host() || '' ) );
}

sub client {
    my $self = shift;

    my $stash = $self->stash();

    return $stash->{client} if $stash->{client};

    my $location = $stash->{location};
    $location ||= $stash->{vendor}->location()
        if $stash->{vendor};

    my $locale;
    $locale = $location->locale() if $location;

    return $stash->{client}
        = VegGuide::Client->new( $self->request(), $locale );
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
