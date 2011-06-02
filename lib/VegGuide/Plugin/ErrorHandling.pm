package VegGuide::Plugin::ErrorHandling;

use strict;
use warnings;

use Catalyst         ();
use Catalyst::Engine ();
use Data::Dump qw/dump/;
use HTML::Entities qw( encode_entities );
use HTTP::Status qw( RC_NOT_FOUND RC_INTERNAL_SERVER_ERROR );
use MRO::Compat;
use VegGuide::JSON;

# I'd really rather _not_ copy this whole thing in here, but it's the
# only way to override how errors are logged. I have to monkey-patch
# rather than subclassing or else NEXT::finalize() ends up calling the
# finalize in Catalyst itself before calling finalize() for other
# plugins (a mess!).
{

    package Catalyst;

    no warnings 'redefine';

    sub finalize {
        my $self = shift;

        for my $error ( @{ $self->error } ) {
            $self->_log_error($error);
        }

        # Allow engine to handle finalize flow (for POE)
        if ( $self->engine->can('finalize') ) {
            $self->engine->finalize($self);
        }
        else {

            $self->finalize_uploads;

            # Error
            if ( $#{ $self->error } >= 0 ) {
                $self->finalize_error;
            }

            $self->finalize_headers;

            # HEAD request
            if ( $self->request->method eq 'HEAD' ) {
                $self->response->body('');
            }

            $self->finalize_body;
        }

        if ( $self->use_stats ) {
            my $elapsed = sprintf '%f', $self->stats->elapsed;
            my $av = $elapsed == 0 ? '??' : sprintf '%.3f', 1 / $elapsed;
            $self->log->info( "Request took ${elapsed}s ($av/s)\n"
                    . $self->stats->report
                    . "\n" );
        }

        return $self->response->status;
    }
}

sub _log_error {
    my $self  = shift;
    my $error = shift;

    # XXX - change this later to log to the apache log?
    #    if ( $error =~ /unknown resource/ )

    my %error = ( uri => $self->request()->uri() . '' );

    if ( my $user = $self->vg_user() ) {
        $error{user} = $user->real_name();
        $error{user} .= q{ - } . $user->user_id()
            if $user->user_id();
    }

    if ( my $ref = $self->request()->referer() ) {
        $error{referer} = $ref;
    }

    $error{error} = $error . '';

    $self->log()->error( VegGuide::JSON->Encode( \%error ) );
}

sub finalize_error {
    my $self = shift;

    if ( $self->debug() ) {
        $self->_finalize_error_with_debug( $self, @_ );
        return;
    }

    my @errors = @{ $self->error() || [] };

    my $status
        = ( grep {/unknown resource|no default/i} @errors )
        ? RC_NOT_FOUND
        : RC_INTERNAL_SERVER_ERROR;

    $self->error( [] );

    $self->response()->content_type('text/html; charset=utf-8');
    $self->response()->status($status);
    $self->response()->body( $self->subreq("/error/$status") );
}

# copied from Catalyst::Engine->finalize_error just so we can set the
# fucking status. GRRRR!
sub _finalize_error_with_debug {
    my $self = shift;
    my $c    = shift;

    $c->res->content_type('text/html; charset=utf-8');
    my $name = $c->config->{name} || join( ' ', split( '::', ref $c ) );

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
        delete $c->req->{_context};
        delete $c->res->{_context};

        # Don't show body parser in the dump
        delete $c->req->{_body};

        # Don't show response header state in dump
        delete $c->res->{_finalized_headers};

        my @infos;
        my $i = 0;
        for my $dump ( $c->dump_these ) {
            my $name = $dump->[0];

            # stored in there for classes with an anon metaclass.
            delete $dump->[1]{__MOP__} if ref $dump->[1];

            my $value = encode_entities( dump( $dump->[1] ) );
            push @infos, sprintf <<"EOF", $name, $value;
<h2><a href="#" onclick="toggleDump('dump_$i'); return false">%s</a></h2>
<div id="dump_$i">
    <pre wrap="">%s</pre>
</div>
EOF
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


    # Trick IE
    $c->res->{body} .= ( ' ' x 512 );

    $c->res->status(500)
        unless $c->res->status;
}


1;
