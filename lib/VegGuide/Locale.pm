package VegGuide::Locale;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema->Locale_t );

use DateTime::Locale;
use Encode       ();
use Encode::Byte ();
use Encode::CN   ();
use Encode::JP   ();
use Encode::TW   ();
use VegGuide::AddressFormat;
use VegGuide::Exceptions qw( data_validation_error );

use VegGuide::Validate
    qw( validate validate_with UNDEF SCALAR ARRAYREF BOOLEAN );

__PACKAGE__->_PreloadLocales;

{

    package DateTime::Locale::en_Ghana;

    # guessing Botswana has similar datetime formatting
    use parent 'DateTime::Locale::en_BW';

    DateTime::Locale->register(
        id           => 'en_Ghana',
        en_language  => 'English',
        en_territory => 'Ghana',

        # Lets this module be reloaded without errors
        replace => 1,
    );
}

{

    package DateTime::Locale::en_Kenya;

    # guessing Botswana has similar datetime formatting
    use parent 'DateTime::Locale::en_BW';

    DateTime::Locale->register(
        id           => 'en_Kenya',
        en_language  => 'English',
        en_territory => 'Kenya',
    );
}

# These objects are singletons, so loading them in the parent process
# can be a big win by keeping them all in shared memory.
sub _PreloadLocales {
    my $class = shift;

    my $schema = VegGuide::Schema->Connect();

    my $locales = $schema->Locale_t->select(
        select =>
            $schema->sqlmaker->DISTINCT( $schema->Locale_t->locale_code_c ),
    );

    while ( my $name = $locales->next ) {
        eval { DateTime::Locale->load($name) };
    }
}

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    return unless $self;
    return $self unless $self->row_object->is_live;

    $self->{dt_locale} = DateTime::Locale->load( $self->locale_code );

    ( $self->{language_code} ) = $self->locale_code =~ /([a-z]+)(?:_\w+)?$/;

    return $self;
}

sub name           { $_[0]->{dt_locale}->name }
sub localized_name { $_[0]->{dt_locale}->native_name }

sub language_name           { $_[0]->{dt_locale}->language }
sub localized_language_name { $_[0]->{dt_locale}->native_language }

sub language_code { $_[0]->{language_code} }

# If a locale has non UTF-8/ISO-8859-1 encodings, then it should allow
# for localized content.  Any locale which fits into the western
# European/English character sets can be displayed in that encoding
# with English descriptions and such.
sub allows_localized_content { $_[0]->encodings ? 1 : 0 }

sub encodings {
    my $self = shift;

    $self->_get_encodings;

    return keys %{ $self->{encodings} };
}

sub _get_encodings {
    my $self = shift;

    return if $self->{encodings};

    $self->{encodings}
        = { map { $_ => 1 }
            map { $_->select('encoding_name') }
            $self->row_object->encodings->all_rows };
}

sub has_encoding {
    my $self     = shift;
    my $encoding = shift;

    $self->_get_encodings;

    return $self->{encodings}{$encoding};
}

sub replace_encodings {
    my $self      = shift;
    my @encodings = @_;

    my $schema = VegGuide::Schema->Connect();

    $schema->begin_work;

    eval {
        my $encodings = $self->row_object->encodings;

        while ( my $e = $encodings->next ) {
            $e->delete;
        }

        foreach my $name (@encodings) {
            $schema->LocaleEncoding_t->insert(
                values => {
                    locale_id     => $self->locale_id,
                    encoding_name => $name
                },
            );
        }

        $schema->commit;
    };

    if ( my $e = $@ ) {
        eval { $schema->rollback };

        die $e;
    }
}

sub address_format { $_[0]->row_object->address_format->select('format') }

sub All {
    my $class = shift;
    my %p     = validate(
        @_, {
            limit      => { type => SCALAR, optional => 1 },
            start      => { type => SCALAR, optional => 1 },
            sort_order => {
                type    => SCALAR,
                default => 'ASC'
            },
        },
    );

    my $limit;
    if ( $p{limit} ) {
        $limit = $p{start} ? [ @p{ 'limit', 'start' } ] : $p{limit};
    }

    my $schema = VegGuide::Schema->Connect();

    my @order_by = ( $schema->Locale_t->locale_code_c, $p{sort_order} );

    return $class->cursor(
        $schema->Locale_t->all_rows(
            order_by => \@order_by,
            $limit ? ( limit => $limit ) : (),
        )
    );
}

{

    # utf8 is excluded because it's always acceptable
    my %exclude = (
        map { $_ => 1 }
            qw( ascii
            ascii-ctrl
            null
            utf8
            utf-8-strict
            hp-roman8
            gsm0338
            AdobeStandardEncoding
            iso-8859-1
            )
    );

    my $exclude_re = qr/^Mac|^nextstep$|^cp/;

    my @encodings
        = ( sort _sort_encodings grep { !( $exclude{$_} || /$exclude_re/ ) }
            Encode->encodings() );

    sub Encodings {
        @encodings;
    }

    sub _sort_encodings {
        if (   ( my ($num1) = $a =~ /^iso-8859-(\d+)/ )
            && ( my ($num2) = $b =~ /^iso-8859-(\d+)/ ) ) {
            return $num1 <=> $num2;
        }
        else {
            return $a cmp $b;
        }
    }
}

1;
