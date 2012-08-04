package VegGuide::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( clean_text list_to_english string_is_empty troolean );

use HTML::Entities qw( encode_entities );
use Text::WikiFormat;

use VegGuide::Validate qw( validate SCALAR_TYPE SCALAR UNDEF );

sub normalize_uri {
    my $url = shift;

    $url =~ s,^(?:http://)?(.+),$1,;

    $url =~ s,/$,, if ( $url =~ tr,/,, ) == 1;

    return $url;
}

sub convert_empty_strings {
    my ( $vals, $char_cols, $num_cols, $tri_state_cols ) = @_;

    foreach my $col (
        grep { $tri_state_cols->{$_} || $char_cols->{$_} || $num_cols->{$_} }
        keys %$vals ) {
        if (   exists $vals->{$col}
            && defined $vals->{$col}
            && !length $vals->{$col} ) {
            $vals->{$col} = (
                $char_cols->{$col} || $tri_state_cols->{$col}
                ? undef
                : 0
            );
        }
    }
}

sub string_is_empty {
    return 1 if !defined $_[0] || !length $_[0];
    return 0;
}

sub days {qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday  )}
sub days_abbr {qw( Mon Tue Wed Thu Fri Sat Sun  )}

{
    my %extensions = (
        jpeg => 'jpeg',
        jpg  => 'jpeg',
        jpe  => 'jpeg',
        png  => 'png',
        gif  => 'gif',
    );

    sub canonical_image_extension {
        return $extensions{ lc shift() };
    }

    sub allowed_image_types {
        return sort keys %{ { map { $_ => 1 } values %extensions } };
    }

    sub allowed_image_types_re {
        return qr/jpeg|gif|png/;
    }
}

# copied from Number::Format::round()
sub round_number {
    my ( $number, $precision ) = @_;

    my $sign       = $number <=> 0;
    my $multiplier = ( 10**$precision );
    my $result     = abs($number);
    $result = int( ( $result * $multiplier ) + .5000001 ) / $multiplier;
    $result = -$result if $sign < 0;
    return $result;
}

sub arrays_match {
    my ( $a1, $a2 ) = @_;

    return 0 if @$a1 != @$a2;

    for ( my $x = 0; $x < @$a1; $x++ ) {
        return 0 if $a1->[$x] ne $a2->[$x];
    }

    return 1;
}

sub sunday_day_of_week {
    my $dt = shift;

    my $dow = ( $dt->day_of_week + 1 );
    return $dow > 7 ? $dow % 7 : $dow;
}

sub list_to_english {
    my @items = @_;

    return $items[0] if @items == 1;

    return "$items[0] and $items[1]" if @items == 2;

    my $last = pop @items;

    my $eng = join ', ', @items;
    $eng .= ', and ' . $last;

    return $eng;
}

sub clean_text (\$) {
    my $text = shift;

    return if string_is_empty( ${$text} );

    ${$text} =~ s/^\s+|\s+$//g;

    ${$text} =~ s/\r\n|\r/\n/g;

    ${$text} =~ s/[\x{2018}\x{2019}\x{201B}]/'/g;
    ${$text} =~ s/[\x{201C}\x{201D}\x{201F}]/"/g;

    return;
}

{
    my $spec = {
        text        => { type               => SCALAR | UNDEF },
        first_class => SCALAR_TYPE( default => '' ),
        class       => SCALAR_TYPE( default => '' ),
    };

    sub text_to_html {
        my %p = validate( @_, $spec );

        return unless grep { defined && length } $p{text};

        my $html = Text::WikiFormat::format(
            $p{text}, {
                header => [ '', "\n", \&_format_header ],
            }, {
                extended       => 1,
                implicit_links => 0,
                absolute_links => 1,
            },
        );

        $html =~ s/<a href/<a rel="nofollow" href/g;

        if ( $p{class} ) {
            $html =~ s/<p>/<p class="$p{class}">/g;
        }

        if ( $p{first_class} ) {
            if ( $p{class} ) {
                $html
                    =~ s/<p class="\Q$p{class}">/<p class="$p{class} $p{first_class}">/;
            }
            else {
                $html =~ s/<p>/<p class="$p{first_class}">/;
            }
        }

        return $html;
    }
}

# XXX - want to offer Markdown eventually too.
sub text_for_rest_response {
    my $text = shift;

    my $html = text_to_html( text => $text );

    return {
        'text/html'                      => $html,
        'text/vnd.vegguide.org-wikitext' => $text,
    };
}

# For some reason, Text::WikiFormat doesn't do HTML entity
# escaping. This is a nasty hack to make that happen.
{
    my $format_line = \&Text::WikiFormat::format_line;

    no warnings 'redefine';
    *Text::WikiFormat::format_line = sub {
        my $text = shift;

        return $format_line->( encode_entities( $text, '<>&"' ), @_ );
    };
}

sub _format_header {
    my $level = length $_[2];
    $level += 2;

    return "<h$level>", Text::WikiFormat::format_line( $_[3], @_[ -2, -1 ] ),
        "</h$level>\n";
}

sub chown_files_for_server {
    return if $>;

    my @files = @_;

    return unless @files;

    my $uid = getpwnam('www-data');
    my $gid = getgrnam('www-data');

    chown $uid, $gid, @files
        or die "Cannot chown $uid $gid @files: $!";
}

sub troolean {
    my $val = shift;

    return 'unknown' unless defined $val;
    return $val ? 'yes' : 'no';
}

1;

