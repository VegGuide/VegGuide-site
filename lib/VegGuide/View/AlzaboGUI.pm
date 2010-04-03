package VegGuide::View::AlzaboGUI;

use strict;
use warnings;

use base 'Catalyst::View::Mason';

use VegGuide::Config;

__PACKAGE__->config(
    comp_root => '/usr/local/share/alzabo/schema',
    data_dir =>
        File::Spec->catdir( VegGuide::Config->CacheDir(), 'alzabo-gui' ),
    in_package    => 'VegGuide::Mason::AlzaboGUI',
    request_class => 'HTML::Mason::Request::Catalyst',
    use_match     => 0,
);

package HTML::Mason::Request::Catalyst;

use base 'HTML::Mason::Request';

sub redirect {
    my $self = shift;
    my $uri  = shift;

    my $status;
    $status = shift if @_;

    $VegGuide::Mason::AlzaboGUI::c->response()->redirect( $uri, $status );

    $self->abort();
}

1;

