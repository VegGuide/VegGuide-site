package VegGuide::Queue;

use strict;
use warnings;

use VegGuide::Validate qw( validate_pos CODEREF_TYPE );

{
    my $spec = (CODEREF_TYPE);

    sub AddToQueue {
        my $class = shift;
        my ($action) = validate_pos( @_, $spec );

        # XXX - This should probably be redone as a Catalyst component with ACCEPT_CONTEXT
        my $r = Apache->request()
            if Apache->can('request');

        if (0) {
            $r->register_cleanup($action);
        }
        else {
            $action->();
        }
    }
}

1;
