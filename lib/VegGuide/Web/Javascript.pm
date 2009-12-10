package VegGuide::Web::Javascript;

use strict;
use warnings;

use JavaScript::Squish;
use JSAN::ServerSide 0.04;
use Path::Class;
use VegGuide::Config;

use Moose;

extends 'VegGuide::Web::CombinedStaticFiles';

has '+header' => (
    default => q[var JSAN = { "use": function () {} };] . "\n",
);

sub _files {
    my $dir = dir( VegGuide::Config->ShareDir(), 'js-source' );

    # Works around an error that comes from JSAN::Parse::FileDeps
    # attempting to assign $_, which is somehow read-only.
    local $_;
    my $js = JSAN::ServerSide->new(
        js_dir => $dir->stringify(),

        # This is irrelevant, as we won't be
        # serving the individual files.
        uri_prefix => '/',
    );

    $js->add('VegGuide');

    return [ map { file($_) } $js->files() ];
}

sub _target_file {
    my $js_dir = dir( VegGuide::Config->VarLibDir(), 'js' );

    $js_dir->mkpath( 0, 0755 );

    return file( $js_dir, 'vegguide-combined.js' );
}

{
    my @Exceptions = (
        qr/\@cc_on/,
        qr/\@if/,
        qr/\@end/,
    );

    sub _squish {
        my $self = shift;
        my $code = shift;

        return $code;
#            unless VegGuide::Config->IsProduction();

        # XXX - this is breaking VegGuide.SitewideSearch for some reason
        return JavaScript::Squish->squish(
            $code,
            remove_comments_exceptions => \@Exceptions,
        );
    }
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
