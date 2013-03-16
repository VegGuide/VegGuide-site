package VegGuide::Email;

use strict;
use warnings;

use Courriel::Builder;
use Email::Sender::Simple qw( sendmail );
use Encode qw( encode );
use HTML::Mason::Interp;
use Try::Tiny;
use VegGuide::Util;

use VegGuide::Validate qw( validate SCALAR_TYPE HASHREF_TYPE BOOLEAN_TYPE );

{
    my $from_address
        = Email::Address->new( 'VegGuide.Org', 'guide@vegguide.org' )
        ->format();

    my $spec = {
        reply_to => SCALAR_TYPE( default  => $from_address ),
        to       => SCALAR_TYPE,
        from     => SCALAR_TYPE( default  => $from_address ),
        subject  => SCALAR_TYPE,
        template => SCALAR_TYPE,
        params   => HASHREF_TYPE( default => {} ),
    };

    sub Send {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $plain_body = _PlainBody(%p);

        my $html_body = _HTMLBody(%p);

        my $email = build_email(
            from( $p{from} ),
            to( $p{to} ),
            subject( $p{subject} ),
            header( 'Reply-To' => $p{reply_to} ),
            header( 'X-Sender' => __PACKAGE__ ),
            plain_body($plain_body),
            html_body($html_body),
        );

        _Send($email);
    }
}

{
    my $Interp = HTML::Mason::Interp->new(
        comp_root => [
            [
                main => File::Spec->catdir(
                    VegGuide::Config->ShareDir(), 'email-templates'
                )
            ],
            [
                lib => File::Spec->catdir(
                    VegGuide::Config->ShareDir(), 'mason'
                )
            ],
        ],
        data_dir => File::Spec->catdir(
            VegGuide::Config->CacheDir(), 'mason', 'email'
        ),
        error_mode       => 'fatal',
        in_package       => 'VegGuide::Mason::Email',
        autohandler_name => 'does-not-exist',
        allow_globals    => ['$c'],
    );

    {

        package VegGuide::Mason::Email;

        use Lingua::EN::Inflect qw( PL PL_V );
        use VegGuide::SiteURI qw( entry_uri region_uri user_uri );
        use VegGuide::Util qw( string_is_empty );
    }

    VegGuide::Util::chown_files_for_server( $Interp->files_written() );

    sub _PlainBody {
        my %p = @_;

        my $body;
        $Interp->out_method( \$body );
        $Interp->exec( "/$p{template}.txt", %{ $p{params} } );

        return $body;
    }

    sub _HTMLBody {
        my %p = @_;

        my $body;
        $Interp->out_method( \$body );
        $Interp->exec( "/$p{template}.html", %{ $p{params} } );

        return $body;
    }
}

sub _Send {
    my $email = shift;

    try {
        sendmail($email);
    }
    catch {
        warn $_;
    };
}

1;
