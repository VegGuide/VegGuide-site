package VegGuide::Web::CSS;

use strict;
use warnings;

use CSS::Minifier qw( minify );
use Path::Class;
use VegGuide::Config;

use Moose;

extends 'VegGuide::Web::CombinedStaticFiles';

sub _files {
    my $dir = dir( VegGuide::Config->ShareDir(), 'css-source' );

    return [
        sort
            grep {
                  !$_->is_dir()
                && $_->basename() =~ /^\d+/
                && $_->basename()
                =~ /\.css$/
            } $dir->children()
    ];
}

sub _target_file {
    my $css_dir = dir( VegGuide::Config->VarLibDir(), 'css' );

    $css_dir->mkpath( 0, 0755 );

    return file( $css_dir, 'vegguide-combined.css' );
}

sub _squish {
    my $self = shift;
    my $css  = shift;

    return minify( input => $css );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
