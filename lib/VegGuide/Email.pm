package VegGuide::Email;

use strict;
use warnings;

use Email::Address;
use Email::MessageID;
use Email::Send;
use Email::MIME::CreateHTML;
use Encode qw( encode );
use HTML::Mason::Interp;
use VegGuide::Queue;
use VegGuide::Util;

use VegGuide::Validate qw( validate SCALAR_TYPE HASHREF_TYPE BOOLEAN_TYPE );


$Email::Send::Sendmail::SENDMAIL = '/usr/sbin/sendmail';
my $Sender = Email::Send->new( { mailer => 'Sendmail' } );

sub TestMode
{
    require Email::Send::Test;
    $Sender = Email::Send->new( { mailer => 'Test' } );
}

{
    my $from_address =
        Email::Address->new( 'VegGuide.Org', 'guide@vegguide.org' )->format();

    my $spec =
        { reply_to => SCALAR_TYPE( default => $from_address ),
          to       => SCALAR_TYPE,
          from     => SCALAR_TYPE( default => $from_address ),
          subject  => SCALAR_TYPE,
          template => SCALAR_TYPE,
          params   => HASHREF_TYPE( default => {} ),
        };
    sub Send
    {
        my $class = shift;
        my %p     = validate( @_, $spec );

        my $text_body = _TextBody(%p);

        my $html_body = _HTMLBody(%p);

        my $email =
            Email::MIME->create_html
                ( header =>
                  [ From         => $p{from},
                    'Reply-To'   => $p{reply_to},
                    To           => $p{to},
                    Subject      => $p{subject},
                    'Message-ID' => Email::MessageID->new(),
                    'Content-Transfer-Encoding' => '8bit',
                    'X-Sender'                  => 'VegGuide::Email',
                  ],
                  body_attributes      => { charset => 'UTF-8' },
                  text_body_attributes => { charset => 'UTF-8' },
                  body                 => encode( 'utf8', $html_body ),
                  text_body            => encode( 'utf8', $text_body ),
                );

        VegGuide::Queue->AddToQueue( sub { _Send($email) } );
    }
}

{
    my $Interp =
        HTML::Mason::Interp->new
            ( comp_root =>
              [ [ main => File::Spec->catdir( VegGuide::Config->ShareDir(), 'email-templates' ) ],
                [ lib  => File::Spec->catdir( VegGuide::Config->ShareDir(), 'mason' ) ],
              ],
              data_dir  => File::Spec->catdir( VegGuide::Config->CacheDir(), 'mason', 'email' ),
              error_mode => 'fatal',
              in_package => 'VegGuide::Mason::Email',
              autohandler_name => 'does-not-exist',
              allow_globals    => [ '$c' ],
            );

    {
        package VegGuide::Mason::Email;

        use Lingua::EN::Inflect qw( PL PL_V );
        use VegGuide::SiteURI qw( entry_uri region_uri user_uri );
        use VegGuide::Util qw( string_is_empty );
    }

    VegGuide::Util::chown_files_for_server( $Interp->files_written() );

    sub _TextBody
    {
        my %p = @_;

        my $body;
        $Interp->out_method( \$body );
        $Interp->exec( "/$p{template}.txt", %{ $p{params} } );

        return $body;
    }

    sub _HTMLBody
    {
        my %p = @_;

        my $body;
        $Interp->out_method( \$body );
        $Interp->exec( "/$p{template}.html", %{ $p{params} } );

        return $body;
    }
}

sub _Send
{
    my $email = shift;

    my $rv = $Sender->send($email);

    warn $rv unless $rv;
}


1;
