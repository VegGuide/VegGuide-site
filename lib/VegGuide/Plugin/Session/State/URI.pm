package VegGuide::Plugin::Session::State::URI;

use namespace::autoclean;

use Moose;

extends 'Catalyst::Plugin::Session::State::URI';

# Some browser keep asking for paths like /user/login_form/-/index.php
sub prepare_path {
    my $c = shift;

    $c->maybe::next::method(@_);

    if (   $c->_sessionid_from_uri()
        && $c->_sessionid_from_uri() !~ /[0-9a-f]{40}/ ) {

        $c->_sessionid_from_uri(undef);

        my $uri = $c->request()->uri();
        $uri =~ s{/-/.+$}{/};

        $c->response()->redirect($uri);
    }

    return;
}

1;
