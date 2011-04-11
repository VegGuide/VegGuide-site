package VegGuide::Image;

use strict;
use warnings;

use File::LibMagic;
use Image::Magick;
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

    my $img = Image::Magick->new();
    $img->read( filename => $self->file() );

    my $i_height = $img->get('height');
    my $i_width  = $img->get('width');

    if (   $height < $i_height
        || $width < $i_width ) {
        my $height_r = $height / $i_height;
        my $width_r  = $width / $i_width;

        my $ratio = $height_r < $width_r ? $height_r : $width_r;

        $img->Scale(
            height => int( $i_height * $ratio ),
            width  => int( $i_width * $ratio ),
        );
    }

    my $status = $img->write(
        filename => $path,
        quality  => $img->get('quality'),
        type     => 'TrueColor',
    );

    die $status if $status;
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
