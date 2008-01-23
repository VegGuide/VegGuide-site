package VegGuide::Feed;

use strict;
use warnings;

use base 'XML::Feed';
use XML::Feed;
use XML::Feed::Entry;
use XML::Feed::RSS;

@XML::Feed::RSS::ISA = @XML::Feed::Atom::ISA = 'VegGuide::Feed';


sub convert
{
    my $self = shift;

    my $new = $self->SUPER::convert(@_);

    if ( $new->format() eq 'Atom' )
    {
        $new->_make_atom_valid();
    }
    else
    {
        $new->_make_rss_10();
    }

    return $new;
}

sub _make_atom_valid
{
    my $self = shift;

    my $root_elem = $self->{atom}->elem();

    my $id_node = $root_elem->ownerDocument()->createElementNS( $self->{atom}->ns(), 'id' );
    $id_node->appendChild( XML::LibXML::Text->new( $self->link() ) );

    $root_elem->insertBefore( $id_node, $root_elem->firstChild() );

    return;
}

sub _make_rss_10
{
    my $self = shift;

    $self->{rss}{output} = '1.0';

    return;
}

if ( $XML::Feed::VERSION <= 0.12 )
{
    # This monkey patch fixes a problem where summary is empty.
    package XML::Feed::Entry;

    no warnings 'redefine';
    *convert = sub {
        my $entry = shift;
        my($format) = @_;
        my $new = __PACKAGE__->new($format);
        for my $field (qw( title link content summary category author id issued modified )) {
            my $val = $entry->$field();
            next unless defined $val;
            next if ref $val && $val->can('body') && ! defined $val->body();
            $new->$field($val);
        }
        $new;
    };

    package XML::Feed::RSS;

    our $PREFERRED_PARSER = "XML::RSS";

    no warnings 'redefine';
    *init_empty = sub {
        my $feed = shift;
        eval "use $PREFERRED_PARSER"; die $@ if $@;
        $feed->{rss} = $PREFERRED_PARSER->new( version => '1.0' );
        $feed->{rss}->add_module(prefix => "content", uri => 'http://purl.org/rss/1.0/modules/content/');
        $feed;
    };
}
