package VegGuide::Image;

use strict;
use warnings;

use File::LibMagic;
use Imager;
use VegGuide::Exceptions qw( data_validation_error );

use Moose;
use Moose::Util::TypeConstraints;

subtype 'VegGuide.File' => as 'Str' => where { -f $_[0] };

has file => (
    is       => 'ro',
    isa      => 'VegGuide.File',
    required => 1,
);

my $Magic = File::LibMagic->new();

has type => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_type',
);

my %Extensions = (
    'image/gif'  => 'gif',
    'image/png'  => 'png',
    'image/jpeg' => 'jpg',
);

has extension => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    lazy     => 1,
    default  => sub { $Extensions{ $_[0]->type() } },
);

my %SupportedTypes = map { $_ => 1 } qw( image/gif image/png image/jpeg );

sub BUILD {
    my $self = shift;

    $SupportedTypes{ $self->type() }
        or data_validation_error 'Invalid file type: ' . $self->type();

    return $self;
}

sub resize {
    my $self   = shift;
    my $height = shift;
    my $width  = shift;
    my $path   = shift;

    my $img = Imager->new( file => $self->file )
        or die Imager->errstr;

    my $scaled = $img->scale(
        ypixels => $height,
        xpixels => $width,
        type    => 'min',
    );

    $scaled->write( file => $path )
        or die $scaled->errstr;

    return;
}

sub _build_type {
    my $self = shift;

    my $type = $Magic->checktype_filename( $self->file() );

    $type =~ s/; .+$//;

    return $type;
}

no Moose;
no Moose::Util::TypeConstraints;

__PACKAGE__->meta()->make_immutable();

1;
