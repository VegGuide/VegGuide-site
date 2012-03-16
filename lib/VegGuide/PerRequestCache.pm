package VegGuide::PerRequestCache;

use strict;
use warnings;

my %Cache;

sub Cache {
    return unless $ENV{PLACK_ENV};

    return \%Cache;
}

sub ClearCache {
    %Cache = ();
}

1;

# This module exists as a hack to help cache data that could change
# per request, but where the object in question is cached across
# requests. This is primarily for the benefit of VegGuide::Location
# objects, which are cached at server startup, but which execute
# various queries like vendor count.

