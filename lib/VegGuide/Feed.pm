package VegGuide::Feed;

use strict;
use warnings;

use base 'XML::Feed';
use XML::Feed;
use XML::Feed::Format::Atom;
use XML::Feed::Format::RSS;

@XML::Feed::Format::RSS::ISA = @XML::Feed::Format::Atom::ISA = 'VegGuide::Feed';


sub convert
{
    my $self = shift;

    my $new = $self->SUPER::convert(@_);

    if ( $new->format() eq 'Atom' )
    {
        $new->_make_atom_valid();
    }

    return $new;
}

sub _make_atom_valid
{
    my $self = shift;

    my $root_elem = $self->{atom}->elem();

    my $link_node = $root_elem->ownerDocument()->createElementNS( $self->{atom}->ns(), 'link' );
    $link_node->setAttribute( rel => 'self' );
    $link_node->setAttribute( href => $self->link() );

    $root_elem->insertBefore( $link_node, $root_elem->firstChild() );

    my $id_node = $root_elem->ownerDocument()->createElementNS( $self->{atom}->ns(), 'id' );
    $id_node->appendChild( XML::LibXML::Text->new( $self->link() ) );

    $root_elem->insertBefore( $id_node, $root_elem->firstChild() );

    return;
}

1;
