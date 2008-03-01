package VegGuide::Controller::User;

use strict;
use warnings;

use base 'VegGuide::Controller::Base';

use Class::Trait 'VegGuide::Role::Controller::Search';

use Captcha::reCAPTCHA;
use URI::FromHash qw( uri );
use VegGuide::Config;
use VegGuide::Search::User;
use VegGuide::SiteURI qw( region_uri user_uri );
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

    my $email = $c->request()->param('email_address');
    my $pw    = $c->request()->param('password');

    my @errors;
    push @errors, 'You must provide an email address.'
        if string_is_empty($email);
    push @errors, 'You must provide a password.'
        if string_is_empty($pw);

    unless (@errors)
    {
        $c->authenticate( { email_address => $email,
                            password      => $pw,
                          } );

        if ( $c->user()->get_object()->email_address() ne $email )
        {
            push @errors,
                'The email or password you provided was not valid.'
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

    $c->add_message( 'Welcome to the site, ' . $c->vg_user()->real_name() );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );
}

sub authentication_DELETE
{
    my $self = shift;
    my $c    = shift;

    $c->authenticate( {} );

    $c->add_message( 'You have been logged out.' );

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
                            undef, undef, { theme => 'blackglass' } );

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

    $c->authenticate( { email_address => $user->email_address,
                        password      => $user_data{password},
                      } );

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
