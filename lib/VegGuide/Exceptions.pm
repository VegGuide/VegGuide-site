package VegGuide::Exceptions;

use strict;
use warnings;

my %E;
BEGIN
{
    %E = ( 'VegGuide::Exception' =>
           { alias => 'error',
             description => 'Generic super-class for VegGuide exceptions' },

           'VegGuide::Exception::Auth' =>
           { isa => 'VegGuide::Exception',
             alias => 'auth_error',
             description => 'User cannot perform the requested action' },

           'VegGuide::Exception::DataValidation' =>
           { isa    => 'VegGuide::Exception',
             alias    => 'data_validation_error',
             fields => [ 'errors' ],
             description => 'Invalid data given to a method/function' },

           'VegGuide::Exception::Params' =>
           { isa => 'VegGuide::Exception',
             alias => 'param_error',
             description => 'Bad parameters given to a method/function' },

           'VegGuide::Exception::System' =>
           { isa => 'VegGuide::Exception',
             alias => 'system_error',
             description => 'System call failed' },

           'VegGuide::Exception::VirtualMethod' =>
           { isa => 'VegGuide::Exception',
             alias => 'virtual_method_error',
             description => 'A virtual method was not implemented in a subclass' },

           'VegGuide::Exception::WebApp::Redirect' =>
           { isa => 'VegGuide::Exception',
             alias => 'redirect_exception',
             description => 'Web app code generated redirect' },
         );
}

{
    package VegGuide::Exception::DataValidation;

    sub messages { @{ $_[0]->errors || [] } }

    sub full_message
    {
        if ( my @m = $_[0]->messages )
        {
            return join "\n", 'Data validation errors: ', @m;
        }
        else
        {
            return $_[0]->SUPER::full_message();
        }
    }
}

{
    package VegGuide::Exception::VirtualMethod;

    sub new
    {
        my $class = shift;
        my $object = shift;

        my $x = 1;
        $x++ while (caller($x))[0]->isa('Exception::Class');
        $x++;

        my $sub = (caller($x))[3];

        my $subclass = ref $object || $object;

        $class->SUPER::new( error =>
                            "The $sub method must be implemented in the $subclass class" );
    }
}

use Exception::Class (%E);

VegGuide::Exception->Trace(1);
VegGuide::Exception->MaxArgLength(50);

use Exporter qw( import );

our @EXPORT_OK = map { $_->{alias} || () } values %E;

use Alzabo::Exceptions;

# A bit of a hack, but not too dangerous
Alzabo::Exception->MaxArgLength(50);

1;
