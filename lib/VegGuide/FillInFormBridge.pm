package VegGuide::FillInFormBridge;

use strict;
use warnings;

use Scalar::Util ();

use VegGuide::Validate qw( validate_pos HASHREF OBJECT );

sub new {
    my $class = shift;
    validate_pos( @_, ( { type => HASHREF | OBJECT } ) x @_ );

    return bless { sources => \@_ }, $class;
}

sub param {
    my $self  = shift;
    my $param = shift;

    foreach my $s ( @{ $self->{sources} } ) {
        if ( Scalar::Util::blessed($s) ) {
            if (   $s->can('is_special_case_form_param')
                && $s->is_special_case_form_param($param) ) {
                my $val = $s->$param();

                return defined $val ? $val : '';
            }
            else {
                return $s->$param() if $s->can($param);
            }
        }
        else {
            return $s->{$param} if exists $s->{$param};
        }
    }

    return;
}

1;

__END__
