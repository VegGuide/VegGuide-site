package VegGuide::Engine;

{
    package Catalyst::Engine;

    use Data::Dump::Streamer;

    no warnings 'redefine';

sub finalize_error {
    my ( $self, $c ) = @_;

    $c->res->content_type('text/html; charset=utf-8');
    my $name = $c->config->{name} || join(' ', split('::', ref $c));

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

        local *Alzabo::Runtime::Row::DDS_freeze = \&ARR_freeze;
        local *Alzabo::Runtime::Table::DDS_freeze = \&ART_freeze;
        local *Alzabo::Runtime::Schema::DDS_freeze = \&ARS_freeze;

        my @infos;
        my $i = 0;
        for my $dump ( $c->dump_these ) {
            my $name  = $dump->[0];

            my $value = '';
            open my $fh, '>', \$value;

            Dump( $dump->[1] )->To($fh)->Out();

            $value = encode_entities($value);
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

    # Return 500
    $c->res->status(500);
}

sub ARR_freeze
{
    my $self = shift;

    return 'row: ' .
        ( $self->is_potential()
          ? 'potential ' . $self->table()->name()
          : $self->id_as_string()
        );
}

sub ART_freeze
{
    my $self = shift;

    return 'table: ' . $self->name();
}

sub ARS_freeze
{
    my $self = shift;

    return 'schema: ' . $self->name();
}

}

1;
