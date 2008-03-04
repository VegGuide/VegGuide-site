package VegGuide::Controller::User;

use strict;
use warnings;

use base 'VegGuide::Controller::Base';

use Class::Trait 'VegGuide::Role::Controller::Search';

use Captcha::reCAPTCHA;
use LWPx::ParanoidAgent;
use Net::OpenID::Consumer;
use URI::FromHash qw( uri );
use VegGuide::Config;
use VegGuide::Search::User;
use VegGuide::SiteURI qw( region_uri site_uri user_uri );
use VegGuide::Util qw( string_is_empty );


sub _set_user : Chained('/') : PathPart('user') : CaptureArgs(1)
{
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    my $user = VegGuide::User->new( user_id => $user_id );

    $c->redirect_and_detach('/')
        unless $user;

    $c->stash()->{user} = $user;

    if ( $c->request()->looks_like_browser() )
    {
        $c->response()->breadcrumbs()->add
            ( uri   => user_uri( user => $user ),
              label => $user->real_name(),
            );
    }
}

sub login_form : Local
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/user/login-form';
}

# This is all rather un-RESTful, from what I can tell, but the only
# RESTful way to do auth is using HTTP auth, which completely sucks in
# too many ways.
sub authentication : Local : ActionClass('+VegGuide::Action::REST') { }

sub authentication_GET_html
{
    my $self = shift;
    my $c    = shift;

    my $method = $c->request()->param('x-tunneled-method');

    if ( $method && $method eq 'DELETE' )
    {
        $self->authentication_DELETE($c);
        return;
    }
    else
    {
        $c->redirect_and_detach( '/user/login_form' );
    }
}

sub authentication_POST
{
    my $self = shift;
    my $c    = shift;

    my $uri   = $c->request()->param('openid_uri');
    my $email = $c->request()->param('email_address');
    my $pw    = $c->request()->param('password');

    my $user;

    if ( ! string_is_empty($uri) )
    {
        $self->_authenticate_openid( $c, $uri );
        return;
    }

    my @errors;

    push @errors, 'You must provide an email address or an OpenID URL.'
        if string_is_empty($email);
    push @errors, 'You must provide a password.'
        if string_is_empty($pw);

    unless (@errors)
    {
        $user = VegGuide::User->new( email_address => $email,
                                     password      => $pw,
                                   );

        if ( $user && $user->email_address() ne $email )
        {
            push @errors,
                'The email or password you provided was not valid.';
        }

        if ( ! $user )
        {
            push @errors,
                'Could not find a user with this email address';
        }
    }

    if (@errors)
    {
        $c->_redirect_with_error
            ( error  => \@errors,
              uri    => '/user/login_form',
              params => { email_address => $email,
                          return_to     => $c->request()->parameters()->{return_to},
                        },
            );
    }

    $self->_login_user( $c, $user );
}

{
    my %OpenIDErrors =
        ( no_identity_server => 'Could not contact an identity server for %s',
          bogus_url          => 'The OpenID URL you provided (%s) is not valid',
          no_head_tag        => 'Got bad data when trying to check your identity server',
          url_fetch_error    => 'Got an error when trying to check your identity server',
        );

    sub _authenticate_openid
    {
        my $self = shift;
        my $c    = shift;
        my $uri  = shift;

        my $csr =
            Net::OpenID::Consumer->new
                ( ua              => LWPx::ParanoidAgent->new(),
                  args            => $c->request()->params(),
                  consumer_secret => sub { $_[0] },
                );

        my $identity = $csr->claimed_identity($uri);

        unless ($identity)
        {
            my $error = sprintf( $OpenIDErrors{ $csr->errcode() }, $uri );

            $c->_redirect_with_error
                ( error  => $error,
                  uri    => '/user/login_form',
                  params => { openid_uri => $uri },
                );
        }

        my %query = ( return_to => $c->request()->param('return_to') );
        $query{remember} = 1
            if $c->request()->param('remember');

        my $return_to =
            site_uri( path      => '/user/openid_authentication',
                      query     => \%query,
                      with_host => 1,
                    );

        my $check_url =
            $identity->check_url
                ( return_to  => $return_to,
                  trust_root => site_uri( path => '/', with_host => 1 ),
                  delayed_return => 1,
                );

        $c->redirect_and_detach($check_url);
    }
}

sub authentication_DELETE
{
    my $self = shift;
    my $c    = shift;

    $c->unset_authen_cookie();

    $c->add_message( 'You have been logged out.' );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );
}

sub openid_authentication : Local
{
    my $self = shift;
    my $c    = shift;

    my $csr =
        Net::OpenID::Consumer->new
            ( ua              => LWPx::ParanoidAgent->new(),
              args            => $c->request()->params(),
              consumer_secret => sub { $_[0] },
            );

    if ( my $setup_url = $csr->user_setup_url() )
    {
        $c->redirect_and_detach($setup_url);
    }
    elsif ( $csr->user_cancel() )
    {
        $c->_redirect_with_error
            ( error  => 'You can still login without OpenID, or make a new account',
              uri    => '/user/login_form',
            );
    }

    my $identity = $csr->verified_identity();
    unless ($identity)
    {
        $c->_redirect_with_error
            ( error  => 'Something went mysteriously wrong trying to authenticate you with OpenID',
              uri    => '/user/login_form',
            );
    }

    my $user = VegGuide::User->new( openid_uri => $identity->url() );

    unless ($user)
    {
        $c->_redirect_with_error
            ( error  => 'Now you need to create a VegGuide.Org account for your OpenID URL',
              uri    => '/user/new_user_form',
              params => { openid_uri => $identity->url() },
            );
    }

    $self->_login_user( $c, $user );
}

sub _login_user
{
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    my %expires = $c->request()->param('remember') ? ( expires => '+1y' ) : ();
    $c->set_authen_cookie( value => { user_id => $user->user_id() },
                           %expires,
                         );

    $c->add_message( 'Welcome to the site, ' . $user->real_name() );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );
}

sub forgot_password_form : Local
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/user/forgot-password-form';
}

sub password_reminder : Local : ActionClass('+VegGuide::Action::REST') { }

sub password_reminder_POST
{
    my $self = shift;
    my $c    = shift;

    my $email = $c->request()->param('email_address');

    my $user;

    my @errors;
    if ( string_is_empty($email) )
    {
        push @errors, 'You must provide an email address.';
    }
    else
    {
        $user = VegGuide::User->new( email_address => $email );
        push @errors, "There is no user with the address $email."
            unless $user;
    }

    if (@errors)
    {
        $c->_redirect_with_error
            ( error  => \@errors,
              uri    => '/user/forgot_password_form',
              params => { email_address => $email,
                          return_to     => $c->request()->parameters()->{return_to},
                        },
            );
    }

    $user->forgot_password();

    $c->add_message( "A message telling you how to change your password has been sent to $email." );

    $c->redirect_and_detach( uri( path => '/user/login_form',
                       query => { return_to => $c->request()->parameters()->{return_to} },
                     )
                );
}

sub change_password_form : Local
{
    my $self   = shift;
    my $c      = shift;
    my $digest = shift;

    my $user = VegGuide::User->new( forgot_password_digest => ( $digest || '' ) );

    $c->redirect_and_detach('/') unless $user;

    $c->stash()->{digest} = $digest;
    $c->stash()->{user}   = $user;

    $c->stash()->{template} = '/user/change-password-form';
}

sub user : Chained('_set_user') : PathPart('') : Args(0) : ActionClass('+VegGuide::Action::REST') { }

sub user_GET_html
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/user/individual/view';
}

sub edit_form : Chained('_set_user') : PathPart('edit_form') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $self->_require_auth( $c,
                          'You must be logged in to edit a user.',
                        );

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_edit_user( $c->stash()->{user} );

    $c->stash()->{template} = '/user/individual/edit-form';
}

sub user_PUT
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    my $digest = $c->request()->param('digest');

    unless ( $c->vg_user()->can_edit_user($user)
             || ( $digest && $user->forgot_password_digest() eq $digest )
           )
    {
        $c->redirect_and_detach('/');
    }

    if ($digest)
    {
        $self->_change_password( $c, $user );
    }
    else
    {
        $self->_update_user( $c, $user );
    }
}

sub _change_password
{
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    eval
    {
        $user->change_password( password  => $c->request()->param('password'),
                                password2 => $c->request()->param('password2'),
                              );
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error  => $e,
              uri    => '/user/change_password_form/' . $user->forgot_password_digest(),
            );
    }

    $c->add_message('Your password has been updated');
    $c->save_param( email_address => $user->email_address() );

    $c->redirect_and_detach( '/user/login_form' );
}

sub _update_user
{
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    my %user_data = $c->request()->user_data($c);

    delete $user_data{is_admin}
        unless $c->vg_user()->is_admin();

    eval
    {
        $user->update(%user_data);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error  => $e,
              uri    => user_uri( user => $user, path => 'edit_form' ),
              params => \%user_data,
            );
    }

    my $subject = $c->vg_user()->user_id() == $user->user_id() ? 'Your' : $user->real_name() . q{'s};

    my $redirect = $c->request()->parameters()->{return_to} || user_uri( user => $user );

    unless ( keys %user_data == 1 && $user_data{entries_per_page} )
    {
        $c->add_message( $subject . ' account has been updated' );
    }

    $c->redirect_and_detach($redirect);
}

sub user_confirm_deletion : Chained('_set_user') : PathPart('deletion_confirmation_form') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_user($user);

    $c->stash()->{thing} = 'user';
    $c->stash()->{name}  = $user->real_name();

    $c->stash()->{uri} = user_uri( user => $user );

    $c->stash()->{template} = '/shared/deletion-confirmation-form';
}

sub user_DELETE
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_delete_user($user);

    my $name = $user->real_name();
    $user->delete( calling_user => $c->vg_user() );

    $c->add_message( "The user $name has been deleted." );

    $c->redirect_and_detach('/user');
}

my $Captcha = Captcha::reCAPTCHA->new();
sub new_user_form : Local
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{captcha_html} =
        $Captcha->get_html( VegGuide::Config->reCAPTCHAPublicKey(),
                            undef, undef, { theme => 'white' } );

    $c->stash()->{template} = '/user/new-user-form';
}

sub users : Path('/user') : ActionClass('+VegGuide::Action::REST') { }

sub users_GET
{
    my $self = shift;
    my $c    = shift;

    my $search = VegGuide::Search::User->new( real_name => ( $c->request()->parameters()->{name} || '' ) );
    $search->set_cursor_params( page  => 1,
                                limit => 0,
                              );

    my $users = $search->users();

    my @users;
    while ( my $user = $users->next() )
    {
        push @users, { user_id   => $user->user_id(),
                       real_name => $user->real_name(),
                     };
    }

    return
        $self->status_ok( $c,
                          entity => \@users,
                        );
}

sub users_GET_html
{
    my $self = shift;
    my $c    = shift;

    my %search_p;

    my $params = $c->request()->parameters();
    if ( $params->{real_name} )
    {
        $search_p{real_name} = $params->{real_name};
    }

    if ( $c->vg_user()->is_admin() && $params->{email_address} )
    {
        $search_p{email_address} = $params->{email_address};
    }

    if ( $params->{order_by} && $params->{order_by} eq 'email_address' && ! $c->vg_user()->is_admin() )
    {
        delete $params->{order_by};
    }

    my $search = VegGuide::Search::User->new(%search_p);

    $c->stash()->{search} = $search;

    $self->_set_search_cursor_params( $c, $search );

    $c->stash()->{template} = '/user/list';
}

my %CaptchaError =
    ( 'incorrect-challenge-sol' => 'You have to fill in the spam check field.',
      'incorrect-captcha-sol'   => 'Looks like you typed the wrong thing in the spam check field.',
      'generic'                 => 'Something went wrong with the spam protection check.',
    );

sub users_POST
{
    my $self = shift;
    my $c    = shift;

    my %user_data = $c->request()->user_data($c);

    delete $user_data{is_admin}
        unless $c->vg_user()->is_admin();

    my $captcha_result =
        $Captcha->check_answer( VegGuide::Config->reCAPTCHAPrivateKey(),
                                $c->request()->address(),
                                $c->request()->param('recaptcha_challenge_field'),
                                $c->request()->param('recaptcha_response_field'),
                              );

    unless ( $captcha_result->{is_valid} )
    {
        my $error = $CaptchaError{ $captcha_result->{error} };
        unless ($error)
        {
            # XXX - need to log this!
            $error = $CaptchaError{generic};
        }

        $c->_redirect_with_error
            ( error  => $error,
              uri    => '/user/new_user_form',
              params => \%user_data,
            );
    }

    my $user;
    eval
    {
        $user = VegGuide::User->create(%user_data);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error  => $e,
              uri    => '/user/new_user_form',
              params => \%user_data,
            );
    }

    $c->set_authen_cookie( value => { user_id => $user->user_id() } );

    $c->add_message( 'Your account has been created.' );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );

}

sub entries : Chained('_set_user') : PathPart('entries') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    if ( $c->stash()->{user}->vendor_count() )
    {
        $c->stash()->{vendors} = $c->stash()->{user}->vendors_by_location();
    }

    $c->stash()->{template} = '/user/individual/entries';
}

sub reviews : Chained('_set_user') : PathPart('reviews') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    if ( $user->review_count() )
    {
        $c->stash()->{reviews} = $user->reviews_by_location();
    }

    if ( $user->ratings_without_review_count() )
    {
        $c->stash()->{ratings} = $user->ratings_without_reviews_by_location();
    }

    $c->stash()->{template} = '/user/individual/reviews';
}

sub history : Chained('_set_user') : PathPart('history') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->is_admin();

    $c->stash()->{logs} = $user->activity_logs()
        if $user->activity_log_count();

    $c->stash()->{template} = '/user/individual/history';
}

sub watch_list : Chained('_set_user') : PathPart('watch_list') : Args(0) : ActionClass('+VegGuide::Action::REST') { }

sub watch_list_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_edit_user($user);

    $c->stash()->{locations} = $user->subscribed_locations();

    $c->stash()->{template} = '/user/individual/watch_list';
}

sub watch_list_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $location_id = $c->request()->param('location_id') || 0;

    my $location =
        VegGuide::Location->new( location_id => $location_id );

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $location && $c->vg_user()->can_edit_user($user);

    $user->subscribe_to_location( location => $location );

    $c->redirect_and_detach( region_uri( location => $location ) );
}

sub watch_list_region : Chained('_set_user') : PathPart('watch_list') : Args(1) : ActionClass('+VegGuide::Action::REST') { }

sub watch_list_region_DELETE : Private
{
    my $self        = shift;
    my $c           = shift;
    my $location_id = shift;

    my $location = VegGuide::Location->new( location_id => $location_id );

    $c->redirect_and_detach('/')
        unless $location;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->can_edit_user($user);

    $user->unsubscribe_from_location( location => $location );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );
}

sub suggestions : Chained('_set_user') : PathPart('suggestions') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->is_admin() || $c->vg_user()->user_id() == $user->user_id();

    $c->stash()->{suggestions} = $user->viewable_suggestions();

    $c->stash()->{template} = '/user/individual/suggestions';
}

sub skins : Chained('_set_user') : PathPart('skins') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach('/')
        unless $c->vg_user()->is_admin() || $c->vg_user()->user_id() == $user->user_id();

    $c->stash()->{skins} = $user->skins();

    $c->stash()->{template} = '/user/individual/skins';
}

{
    # Monkey-patch to shut up various warnings
    package Net::OpenID::Consumer;

    no warnings 'redefine';

sub _find_semantic_info {
    my Net::OpenID::Consumer $self = shift;
    my $url = shift;
    my $final_url_ref = shift;

    my $trim_hook = sub {
        my $htmlref = shift;
        # trim everything past the body.  this is in case the user doesn't
        # have a head document and somebody was able to inject their own
        # head.  -- brad choate
        $$htmlref =~ s/<body\b.*//is;
    };

    my $doc = $self->_get_url_contents($url, $final_url_ref, $trim_hook) or
        return;

    # find <head> content of document (notably: the first head, if an attacker
    # has added others somehow)
    return $self->_fail("no_head_tag", "Couldn't find OpenID servers due to no head tag")
        unless $doc =~ m!<head[^>]*>(.*?)</head>!is;
    my $head = $1;

    my $ret = {
        'openid.server' => undef,
        'openid.delegate' => undef,
        'foaf' => undef,
        'foaf.maker' => undef,
        'rss' => undef,
        'atom' => undef,
    };

    # analyze link/meta tags
    while ($head =~ m!<(link|meta)\b([^>]+)>!g) {
        my ($type, $val) = ($1, $2);
        my $temp;

        # OpenID servers / delegated identities
        # <link rel="openid.server" href="http://www.livejournal.com/misc/openid.bml" />
        if ($type eq "link" &&
            $val =~ /\brel=.openid\.(server|delegate)./i && ($temp = $1) &&
            $val =~ m!\bhref=[\"\']([^\"\']+)[\"\']!i) {
            $ret->{"openid.$temp"} = $1;
            next;
        }

        # FOAF documents
        #<link rel="meta" type="application/rdf+xml" title="FOAF" href="http://brad.livejournal.com/data/foaf" />
        if ($type eq "link" &&
            $val =~ m!title=.foaf.!i &&
            $val =~ m!rel=.meta.!i &&
            $val =~ m!type=.application/rdf\+xml.!i &&
            $val =~ m!href=[\"\']([^\"\']+)[\"\']!i) {
            $ret->{"foaf"} = $1;
            next;
        }

        # FOAF maker info
        # <meta name="foaf:maker" content="foaf:mbox_sha1sum '4caa1d6f6203d21705a00a7aca86203e82a9cf7a'" />
        if ($type eq "meta" &&
            $val =~ m!name=.foaf:maker.!i &&
            $val =~ m!content=([\'\"])(.*?)\1!i) {
            $ret->{"foaf.maker"} = $2;
            next;
        }

        if ($type eq "meta" &&
            $val =~ m!name=.foaf:maker.!i &&
            $val =~ m!content=([\'\"])(.*?)\1!i) {
            $ret->{"foaf.maker"} = $2;
            next;
        }

        # RSS
        # <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.livejournal.com/~brad/data/rss" />
        if ($type eq "link" &&
            $val =~ m!rel=.alternate.!i &&
            $val =~ m!type=.application/rss\+xml.!i &&
            $val =~ m!href=[\"\']([^\"\']+)[\"\']!i) {
            $ret->{"rss"} = $1;
            next;
        }

        # Atom
        # <link rel="alternate" type="application/atom+xml" title="Atom" href="http://www.livejournal.com/~brad/data/rss" />
        if ($type eq "link" &&
            $val =~ m!rel=.alternate.!i &&
            $val =~ m!type=.application/atom\+xml.!i &&
            $val =~ m!href=[\"\']([^\"\']+)[\"\']!i) {
            $ret->{"atom"} = $1;
            next;
        }
    }

    # map the 4 entities that the spec asks for
    my $emap = {
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'amp' => '&',
    };
    foreach my $k (keys %$ret) {
        next unless $ret->{$k};
        $ret->{$k} =~ s/&(\w+);/$emap->{$1} || ""/eg;
    }

    {
        no warnings 'uninitialized';
        $self->_debug("semantic info ($url) = " . join(", ", %$ret));
    }

    return $ret;
}

package Net::OpenID::ClaimedIdentity;


sub check_url {
    my Net::OpenID::ClaimedIdentity $self = shift;
    my (%opts) = @_;

    my $return_to   = delete $opts{'return_to'};
    my $trust_root  = delete $opts{'trust_root'};
    my $delayed_ret = delete $opts{'delayed_return'};

    Carp::croak("Unknown options: " . join(", ", keys %opts)) if %opts;
    Carp::croak("Invalid/missing return_to") unless $return_to =~ m!^https?://!;

    my $csr = $self->{consumer};

    my $ident_server = $self->{server} or
        Carp::croak("No identity server");

    # get an assoc (or undef for dumb mode)
    my $assoc = Net::OpenID::Association::server_assoc($csr, $ident_server);

    my $identity_arg = $self->{'delegate'} || $self->{'identity'};

    # make a note back to ourselves that we're using a delegate
    if ($self->{'delegate'}) {
        OpenID::util::push_url_arg(\$return_to,
                                   "oic.identity",  $self->{identity});
    }

    # add a HMAC-signed time so we can verify the return_to URL wasn't spoofed
    my $sig_time = time();
    my $c_secret = $csr->_get_consumer_secret($sig_time);
    my $sig = substr(OpenID::util::hmac_sha1_hex($sig_time, $c_secret), 0, 20);
    OpenID::util::push_url_arg(\$return_to,
                               "oic.time", "${sig_time}-$sig");

    my $curl = $ident_server;
    OpenID::util::push_url_arg(\$curl,
                               "openid.mode",           ($delayed_ret ? "checkid_setup" : "checkid_immediate"),
                               "openid.identity",       $identity_arg,
                               "openid.return_to",      $return_to,

                               ($trust_root ?
                                ("openid.trust_root",   $trust_root) : ()),

                               ($assoc ?
                                ("openid.assoc_handle", $assoc->handle) : ()),
                               );

    {
        no warnings 'uninitialized';
        $self->{consumer}->_debug("check_url for (del=$self->{delegate}, id=$self->{identity}) = $curl");
    }

    return $curl;
}


package OpenID::util;

sub hmac {
    my($data, $key, $hash_func, $block_size) = @_;
    $block_size ||= 64;
    $key = &$hash_func($key) if length($key) > $block_size;

    my $k_ipad = $key ^ (chr(0x36) x $block_size);
    no warnings 'numeric';
    my $k_opad = $key ^ (chr(0x5c) x $block_size);

    &$hash_func($k_opad, &$hash_func($k_ipad, $data));
}

}


1;

__END__

=head1 NAME

VegGuide::Controller::User - Catalyst Controller

=head1 SYNOPSIS

See L<VegGuide>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=over 4

=back

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
