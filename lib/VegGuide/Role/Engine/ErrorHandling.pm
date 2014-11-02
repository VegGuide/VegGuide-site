package VegGuide::Role::Engine::ErrorHandling;

use strict;
use warnings;

use Catalyst         ();
use Catalyst::Engine ();
use Data::Dump qw/dump/;
use HTML::Entities qw( encode_entities );
use HTTP::Status qw( RC_NOT_FOUND RC_INTERNAL_SERVER_ERROR );

use Moose::Role;

around finalize => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig() if $self->debug();

    for my $error ( @{ $self->error } ) {
        $self->_log_error($error);
    }

    my $log_class = ref $self->log();

    # Catalyst->finalize always calls $self->log->error for each error. We've
    # already logged the errors we care about, however. It'd be better to
    # provide our own log object that did the filtering and formatting we
    # want, but this seems to be surprisingly complicated, at least from
    # looking at Catalyst::Plugin::Log::Dispatch.
    {
        no strict 'refs';
        no warnings 'redefine';
        local *{ $log_class . '::error' } = sub { return; };
        return $self->$orig();
    }
};

sub _log_error {
    my $self  = shift;
    my $error = shift;

    return if $error =~ /Software caused connection abort/;
    return if $error =~ /unknown resource/i;

    my %error = (
        uri   => $self->request()->uri() . '',
        epoch => time(),
    );

    if ( my $user = $self->vg_user() ) {
        $error{user} = $user->real_name();
        $error{user} .= q{ - } . $user->user_id()
            if $user->user_id();
    }

    if ( my $ref = $self->request()->referer() ) {
        $error{referer} = $ref;
    }

    $error{user_agent} = $self->request()->user_agent();

    $error{error} = $error . '';

    $self->log()->error( VegGuide::JSON->Encode( \%error ) );
}

sub finalize_error {
    my $self = shift;

    my @errors = @{ $self->error() || [] };

    my $status
        = ( grep {/unknown resource|no default/i} @errors )
        ? RC_NOT_FOUND
        : RC_INTERNAL_SERVER_ERROR;

    $self->error( [] );

    $self->response()->content_type('text/html; charset=utf-8');
    $self->response()->status($status);

    if ( $self->debug() ) {
        $self->_finalize_error_with_debug( $self, @_ );
        return;
    }
    else {
        $self->response()->body( $self->subreq("/error/$status") );
    }
}

# copied from Catalyst::Engine->finalize_error (5.90075) just so we can set
# the fucking status. GRRRR!
sub _finalize_error_with_debug {
    my ( $self, $c ) = @_;

    $c->res->content_type('text/html; charset=utf-8');
    my $name = ref($c)->config->{name} || join(' ', split('::', ref $c));
    
    # Prevent Catalyst::Plugin::Unicode::Encoding from running.
    # This is a little nasty, but it's the best way to be clean whether or
    # not the user has an encoding plugin.

    if ($c->can('encoding')) {
      $c->{encoding} = '';
    }

    my ( $title, $error, $infos );
    if ( $c->debug ) {

        # For pretty dumps
        $error = join '', map {
                '<p><code class="error">'
              . encode_entities($_)
              . '</code></p>'
        } @{ $c->error };
        $error ||= 'No output';
        $error = qq{<pre wrap="">$error</pre>};
        $title = $name = "$name on Catalyst $Catalyst::VERSION";
        $name  = "<h1>$name</h1>";

        # Don't show context in the dump
        $c->res->_clear_context;

        # Don't show body parser in the dump
        $c->req->_clear_body;

        my @infos;
        my $i = 0;
        for my $dump ( $c->dump_these ) {
            push @infos, $self->_dump_error_page_element($i, $dump);
            $i++;
        }
        $infos = join "\n", @infos;
    }
    else {
        $title = $name;
        $error = '';
        $infos = <<"";
<pre>
(en) Please come back later
(fr) SVP veuillez revenir plus tard
(de) Bitte versuchen sie es spaeter nocheinmal
(at) Konnten's bitt'schoen spaeter nochmal reinschauen
(no) Vennligst prov igjen senere
(dk) Venligst prov igen senere
(pl) Prosze sprobowac pozniej
(pt) Por favor volte mais tarde
(ru) Попробуйте еще раз позже
(ua) Спробуйте ще раз пізніше
(it) Per favore riprova più tardi
</pre>

        $name = '';
    }
    $c->res->body( <<"" );
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <meta http-equiv="Content-Language" content="en" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>$title</title>
    <script type="text/javascript">
        <!--
        function toggleDump (dumpElement) {
            var e = document.getElementById( dumpElement );
            if (e.style.display == "none") {
                e.style.display = "";
            }
            else {
                e.style.display = "none";
            }
        }
        -->
    </script>
    <style type="text/css">
        body {
            font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                         Tahoma, Arial, helvetica, sans-serif;
            color: #333;
            background-color: #eee;
            margin: 0px;
            padding: 0px;
        }
        :link, :link:hover, :visited, :visited:hover {
            color: #000;
        }
        div.box {
            position: relative;
            background-color: #ccc;
            border: 1px solid #aaa;
            padding: 4px;
            margin: 10px;
        }
        div.error {
            background-color: #cce;
            border: 1px solid #755;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
        }
        div.infos {
            background-color: #eee;
            border: 1px solid #575;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
        }
        div.name {
            background-color: #cce;
            border: 1px solid #557;
            padding: 8px;
            margin: 4px;
        }
        code.error {
            display: block;
            margin: 1em 0;
            overflow: auto;
        }
        div.name h1, div.error p {
            margin: 0;
        }
        h2 {
            margin-top: 0;
            margin-bottom: 10px;
            font-size: medium;
            font-weight: bold;
            text-decoration: underline;
        }
        h1 {
            font-size: medium;
            font-weight: normal;
        }
        /* from http://users.tkk.fi/~tkarvine/linux/doc/pre-wrap/pre-wrap-css3-mozilla-opera-ie.html */
        /* Browser specific (not valid) styles to make preformatted text wrap */
        pre {
            white-space: pre-wrap;       /* css-3 */
            white-space: -moz-pre-wrap;  /* Mozilla, since 1999 */
            white-space: -pre-wrap;      /* Opera 4-6 */
            white-space: -o-pre-wrap;    /* Opera 7 */
            word-wrap: break-word;       /* Internet Explorer 5.5+ */
        }
    </style>
</head>
<body>
    <div class="box">
        <div class="error">$error</div>
        <div class="infos">$infos</div>
        <div class="name">$name</div>
    </div>
</body>
</html>

    # Trick IE. Old versions of IE would display their own error page instead
    # of ours if we'd give it less than 512 bytes.
    $c->res->{body} .= ( ' ' x 512 );

    $c->res->{body} = Encode::encode("UTF-8", $c->res->{body});

    # XXX - this is the only difference from Catalyst 5.90075
    $c->res->status(500)
        unless $c->res->status;
}

# XXX - copied from Catalyst 5.90075
sub _dump_error_page_element {
    my ($self, $i, $element) = @_;
    my ($name, $val)  = @{ $element };

    # This is fugly, but the metaclass is _HUGE_ and demands waaay too much
    # scrolling. Suggestions for more pleasant ways to do this welcome.
    local $val->{'__MOP__'} = "Stringified: "
        . $val->{'__MOP__'} if ref $val eq 'HASH' && exists $val->{'__MOP__'};

    my $text = encode_entities( dump( $val ));
    sprintf <<"EOF", $name, $text;
<h2><a href="#" onclick="toggleDump('dump_$i'); return false">%s</a></h2>
<div id="dump_$i">
    <pre wrap="">%s</pre>
</div>
EOF
}

1;
