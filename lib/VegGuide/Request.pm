package VegGuide::Request;

use strict;
use warnings;

use NEXT;
use base 'Catalyst::Request::REST';

use List::MoreUtils qw( all );
use VegGuide::Util qw( string_is_empty );

use VegGuide::Validate
    qw( validate validate_pos
        HASHREF_TYPE BOOLEAN_TYPE
        SCALAR_OR_ARRAYREF_TYPE );


sub method
{
    my $self = shift;

    return $self->NEXT::method(@_)
        if @_;

    return $self->{__method} if $self->{__method};

    my $method = $self->NEXT::method();

    return $method unless $method && uc $method eq 'POST';

    my $tunneled = $self->param('x-tunneled-method');

    return $self->{__method} = $tunneled ? $tunneled : $method;
}

{
    my %HTMLTypes = qw( text/html application/xhtml+xml );

    sub looks_like_browser
    {
        my $self = shift;

        my $with = $self->header('x-requested-with');
        return 0
            if $with && $with eq 'HTTP.Request';

        my $forced_type = $self->param('content-type');
        return 0
            if $forced_type && ! $HTMLTypes{$forced_type};

        # IE7 does not say it accepts any form of html, but _does_
        # accept */* (helpful;)
        return 1
            if grep { $_ eq '*/*' } @{ $self->accepted_content_types() };

        return 1
            if grep { $self->accepts($_) } keys %HTMLTypes;

        return 0
            if @{ $self->accepted_content_types() };

        # If the client did not specify any content types at all,
        # assume they are a browser.
        return 1;
    }
}

sub location_data
{
    my $self = shift;

    my %data =
        $self->_params_for_classes( classes => 'VegGuide::Location' );

    $data{skip_duplicate_check} = $self->param('skip_duplicate_check');

    delete @data{ 'parent_location_id', 'location_id', 'user_id' };

    return %data;
}

sub vendor_data
{
    my $self = shift;

    my %data =
        $self->_params_for_classes( classes => 'VegGuide::Vendor' );

    my $params = $self->parameters();

    for my $k ( qw( new_neighborhood new_localized_neighborhood category_id ) )
    {
        $data{$k} = $params->{$k}
            if defined $params->{$k};
    }

    for my $k ( qw( cuisine_id payment_option_id attribute_id ) )
    {
        $data{$k} = defined $params->{$k} ? $params->{$k} : [];
    }

    $data{payment_option_id} = []
        if $data{is_cash_only};

    if ( $data{close_date} && $data{close_date} eq 'open' )
    {
        $data{close_date} = undef;
    }

    delete $data{vendor_id};

    return %data;
}

sub user_data
{
    my $self = shift;

    my %data =
        $self->_params_for_classes( classes => 'VegGuide::User' );

    my $params = $self->parameters();
    $data{password2} = $params->{password2}
        if defined $params->{password2};

    delete @data{ 'password', 'password2' }
        if all { string_is_empty($_) } @data{ 'password', 'password2' };

    return %data;
}

sub locale_data
{
    my $self = shift;

    return $self->_params_for_classes( classes => 'VegGuide::Locale' );
}

sub skin_data
{
    my $self = shift;

    my %data = $self->_params_for_classes( classes => 'VegGuide::Skin' );

    $data{home_location_id} = $self->param('location_id');

    return %data;
}

{
    my $spec = { classes    => SCALAR_OR_ARRAYREF_TYPE,
                 include_pk => BOOLEAN_TYPE( default => 0 ),
               };
    sub _params_for_classes
    {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $params = $self->parameters();

        my @c = ref $p{classes} ? @{ $p{classes} } : $p{classes};

        my %data;
        foreach my $col ( map { $_->columns() } @c )
        {
            next if $col->is_primary_key() && ! $p{include_pk};

            my $name = $col->name();

            next unless exists $params->{$name};

            $data{$name} = $params->{$name};

            if ( defined $data{$name} && $data{$name} eq '' )
            {
                if ( $col->is_character() || $col->is_date() || $col->is_datetime() )
                {
                    $data{$name} = undef;
                }
                elsif ( $col->type() eq 'TINYINT' && $col->length() == 1 && $col->nullable() )
                {
                    $data{$name} = undef;
                }
                else
                {
                    $data{$name} = 0;
                }
            }
        }

        return %data;
    }
}


1;
