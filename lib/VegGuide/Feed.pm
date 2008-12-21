package VegGuide::Feed;

use strict;
use warnings;

use base 'XML::Feed';
use XML::Feed;
use XML::Feed::Format::Atom;
use XML::Feed::Format::RSS;

@XML::Feed::Format::RSS::ISA = @XML::Feed::Format::Atom::ISA = 'VegGuide::Feed';


sub is_entries_only
{
    my $self = shift;

    if (@_)
    {
        $self->{is_entries_only} = shift;
    }

    return $self->{is_entries_only};
}

sub is_reviews_only
{
    my $self = shift;

    if (@_)
    {
        $self->{is_reviews_only} = shift;
    }

    return $self->{is_reviews_only};
}

sub convert
{
    my $self = shift;

    my $new = $self->SUPER::convert(@_);

    $new->is_entries_only( $self->is_entries_only() );
    $new->is_reviews_only( $self->is_reviews_only() );

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

    my $self_link = $self->link() . '/recent.atom';

    if ( $self->is_entries_only() )
    {
        $self_link .= '?entries_only=1';
    }
    elsif ( $self->is_reviews_only() )
    {
        $self_link .= '?reviews_only=1';
    }

    $link_node->setAttribute( href => $self_link );

    $root_elem->insertBefore( $link_node, $root_elem->firstChild() );

    my $id_node = $root_elem->ownerDocument()->createElementNS( $self->{atom}->ns(), 'id' );
    $id_node->appendChild( XML::LibXML::Text->new( $self->link() ) );

    $root_elem->insertBefore( $id_node, $root_elem->firstChild() );

    return;
}

1;
