package VegGuide::Plugin::Unicode::Encoding;

use strict;
use warnings;

use base 'Catalyst::Plugin::Unicode::Encoding';

# Simply ignoring the request at least prevents the process from throwing an
# error. We can't redirect here because it's too early in the request handling
# process :(
sub handle_unicode_encoding_exception { return }

1;
