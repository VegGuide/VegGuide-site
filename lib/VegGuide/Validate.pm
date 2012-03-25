package VegGuide::Validate;

use strict;
use warnings;

use parent 'Exporter';

use Params::Validate qw(:types);
use Scalar::Util qw( blessed );
use VegGuide::Exceptions qw( param_error );

my %Types;

BEGIN {
    %Types = (
        SCALAR_OR_ARRAYREF_TYPE => { type => SCALAR | ARRAYREF },

        POS_INTEGER_TYPE => {
            type      => SCALAR,
            regex     => qr/^\d+$/,
            callbacks => {
                'is > 0' => sub { $_[0] && $_[0] > 0 }
            },
        },

        ERROR_OR_EXCEPTION_TYPE => {
            callbacks => {
                'is a scalar or exception object' => sub {
                    return 1 unless ref $_[0];
                    return 1 if eval { @{ $_[0] } } && !grep {ref} @{ $_[0] };
                    return 0 unless blessed $_[0];
                    return 1
                        if $_[0]->can('messages') || $_[0]->can('message');
                    return 0;
                },
            },
        },

        FILE_TYPE => {
            type      => SCALAR,
            callbacks => {
                'file exists' => sub { -f $_[0] }
            },
        },
    );

    for my $t ( grep {/^[A-Z]+$/} @Params::Validate::EXPORT_OK ) {
        my $name = $t . '_TYPE';
        $Types{$name} = { type => eval $t };
    }

    for my $class (qw( Location NewsItem User Vendor VendorImage )) {
        ( my $name = $class ) =~ s/([a-z])([A-Z])/${1}_$2/g;
        $Types{ uc $name . '_TYPE' } = { isa => "VegGuide::${class}" };
    }

    for my $t ( keys %Types ) {
        my %t   = %{ $Types{$t} };
        my $sub = sub {
            param_error "Invalid additional args for $t: [@_]" if @_ % 2;
            return { %t, @_ };
        };

        no strict 'refs';
        *{$t} = $sub;
    }
}

our %EXPORT_TAGS = ( types => [ keys %Types ] );
our @EXPORT_OK = keys %Types;

my %MyExports = map { $_ => 1 }
    @EXPORT_OK,
    map {":$_"} keys %EXPORT_TAGS;

sub import {
    my $class = shift;

    my $caller = caller;

    my @pv_export = grep { !$MyExports{$_} } @_;

    {
        eval <<"EOF";
package $caller;

use Params::Validate qw(@pv_export);
Params::Validate::set_options( on_fail => \\&VegGuide::Exceptions::param_error );
EOF

        die $@ if $@;
    }

    $class->export_to_level( 1, undef, grep { $MyExports{$_} } @_ );
}

1;

__END__
