package VegGuide::Types::Internal;

use strict;
use warnings;

use Email::Valid;
use MooseX::Types -declare => [
    qw( PosInt
        PosOrZeroInt
        NonEmptyStr
        ErrorForSession
        URIStr
        ValidPermissionType
        )
];
use MooseX::Types::Moose qw( Int Str Defined );

subtype PosInt,
    as Int,
    where { $_ > 0 },
    message {'This must be a positive integer'};

subtype PosOrZeroInt,
    as Int,
    where { $_ >= 0 },
    message {'This must be an integer >= 0'};

subtype NonEmptyStr,
    as Str,
    where { length $_ >= 0 },
    message {'This string must not be empty'};

subtype ErrorForSession, as Defined, where {
    return 1;
    return 1 unless ref $_;
    return 1 if eval { @{$_} } && !grep {ref} @{$_};
    return 0 unless blessed $_;
    return 1 if $_->can('messages') || $_->can('message');
    return 0;
};

subtype URIStr, as NonEmptyStr;

coerce URIStr, from class_type('URI'), via { $_->canonical() };

subtype ValidPermissionType,
    as NonEmptyStr,
    where {qr/^(?:public|public-read|private)$/};

1;

