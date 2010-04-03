package VegGuide::Role::Controller::Comment;

use strict;
use warnings;

use Class::Trait 'base';

sub _comment_post {
    my $self      = shift;
    my $c         = shift;
    my $thing     = shift;
    my $error_uri = shift;

    my $user
        = VegGuide::User->new( user_id => $c->request()->param('user_id') );

    my $comment;
    eval {
        $comment = $thing->add_or_update_comment(
            user         => $user,
            comment      => $c->request()->param('comment'),
            calling_user => $c->vg_user(),
        );

        my $rating = $c->request()->param('rating');

        if (
            $rating
            && (   $user->user_id() == $c->vg_user()->user_id()
                || $c->vg_user()->is_admin() )
            ) {
            $thing->add_or_update_rating(
                user   => $user,
                rating => $rating,
            );
        }
        elsif ( defined $rating ) {
            $thing->delete_rating( user => $user );
        }
    };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error  => $e,
            uri    => $error_uri,
            params => $c->request()->parameters(),
        );
    }

    return $comment;
}

1;
