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

1;
