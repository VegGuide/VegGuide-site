package VegGuide::VendorImage;

use strict;
use warnings;

use VegGuide::Schema;
use VegGuide::AlzaboWrapper
    ( table => VegGuide::Schema->Schema()->VendorImage_t() );

use VegGuide::Exceptions qw( auth_error data_validation_error );
use VegGuide::Validate qw( validate validate_with SCALAR_TYPE
                           USER_TYPE VENDOR_TYPE FILE_TYPE POS_INTEGER_TYPE );

use File::Copy qw( copy );
use File::MMagic;
use File::Path qw( mkpath );
use File::Spec;
use Image::Magick;
use Image::Size qw( imgsize );
use VegGuide::Config;


{
    my $spec = { vendor_id     => POS_INTEGER_TYPE,
                 display_order => POS_INTEGER_TYPE,
               };
    sub _new_row
    {
        my $class = shift;
        my %p = validate_with( params => \@_,
                               spec   => $spec,
                               allow_extra => 1,
                             );

        my @where;
        if ( $p{vendor_id} && $p{display_order} )
        {
            push @where,
                ( [ $class->table()->vendor_id_c(), '=', $p{vendor_id} ],
                  [ $class->table()->display_order_c(), '=', $p{display_order} ],
                );
        }

        return $class->table()->one_row( where => \@where );
    }
}

{
    my $spec = { file    => FILE_TYPE,
                 caption => SCALAR_TYPE( default => undef ),
                 user    => USER_TYPE,
                 vendor  => VENDOR_TYPE,
               };

    my $Magic = File::MMagic->new();

    my %SupportedTypes = map { $_ => 1 } qw( image/gif image/png image/jpeg );
    my %Extensions     = ( 'image/gif'  => 'gif',
                           'image/png'  => 'png',
                           'image/jpeg' => 'jpg',
                         );

    sub create_from_file
    {
        my $class = shift;
        my %p     = validate( @_, $spec );

        my $type = $Magic->checktype_filename( $p{file} );

        data_validation_error 'Invalid file type: ' . $type->type()
            unless $SupportedTypes{ $type || '' };

        my $image =
            $class->create( vendor_id => $p{vendor}->vendor_id(),
                            user_id   => $p{user}->user_id(),
                            caption   => $p{caption},
                            extension => $Extensions{$type},
                          );

        mkpath( $image->dir(), 0, 0755 );

        my $to = $image->original_path();
        copy( $p{file}, $to )
            or die "Cannot copy $p{file} => $to: $!";

        $image->_make_resized_images();
    }
}

sub create
{
    my $class = shift;
    my %p     = @_;

    my $schema = VegGuide::Schema->Connect();

    $schema->begin_work();

    my $image;
    eval
    {
        my $sql = <<'EOF';
SELECT IFNULL( MAX( display_order ), 0 ) + 1
  FROM VendorImage
 WHERE vendor_id = ?
FOR UPDATE
EOF

        my $display_order = $schema->driver()->one_row( sql => $sql, bind => $p{vendor_id} );

        $image = $class->SUPER::create( %p, display_order => $display_order );

        $schema->commit();
    };

    die $@ if $@;

    return $image;
}

{
    my @Small = ( 250, 250 );
    my @Large = ( 400, 620 );

    sub _make_resized_images
    {
        my $self = shift;

        $self->_resize_image( @Small, 'small' );
        $self->_resize_image( @Large, 'large' );
    }
}

sub _resize_image
{
    my $self   = shift;
    my $height = shift;
    my $width  = shift;
    my $size   = shift;

    my $img = Image::Magick->new();
    $img->read( filename => $self->original_path() );

    my $i_height = $img->get('height');
    my $i_width  = $img->get('width');

    if ( $height < $i_height
         ||
         $width  < $i_width
       )
    {
        my $height_r = $height / $i_height;
        my $width_r  = $width / $i_width;

        my $ratio = $height_r < $width_r ? $height_r : $width_r;

        $img->Scale( height => int( $i_height * $ratio ),
                     width  => int( $i_width * $ratio ),
                   );
    }

    my $meth = $size . '_path';
    $img->write( filename => $self->$meth(),
                 quality  => $img->get('quality'),
                 type     => 'Palette',
               );

}

BEGIN
{
    for my $size ( qw( original small large ) )
    {
        my $filename_method =
            sub { return $_[0]->base_filename() . q{-} . $size . q{.} . $_[0]->extension() };

        my $filename_meth_name = $size . '_filename';
        my $path_method =
            sub { return File::Spec->catfile( $_[0]->dir(), $_[0]->$filename_meth_name() ) };

        my $uri_method =
            sub { return File::Spec::Unix->catfile( '', $_[0]->_uri_prefix(), $_[0]->$filename_meth_name() ) };

        my $path_meth_name = $size . '_path';

        my $dimensions_key = $size . '_dimensions';
        my $dimensions_method =
            sub {
                my $self = shift;

                $self->{$dimensions_key} ||= [ imgsize( $self->$path_meth_name() ) ];

                return $self->{$dimensions_key};
              };

        my $dimensions_meth_name = q{_} . $size . '_dimensions';
        my $width_method  = sub { $_[0]->$dimensions_meth_name()->[0] };
        my $height_method = sub { $_[0]->$dimensions_meth_name()->[1] };

        no strict 'refs';
        *{ $filename_meth_name }  = $filename_method;
        *{ $path_meth_name }      = $path_method;
        *{ $size . '_uri' }       = $uri_method;
        *{ $dimensions_meth_name} = $dimensions_method;
        *{ $size . '_height' }    = $height_method;
        *{ $size . '_width' }     = $width_method;
    }
}

sub _uri_prefix
{
    my $self = shift;

    return ( 'entry-images', $self->vendor_id() );
}

sub dir
{
    my $self = shift;

    return File::Spec->catdir( VegGuide::Config->VarLibDir(), $self->_uri_prefix() );
}

sub base_filename
{
    my $self = shift;

    return join '-', $self->vendor_id(), $self->vendor_image_id();
}

sub make_image_first
{
    my $self = shift;

    my $order = $self->display_order();

    return if $order == 1;

    my $schema = VegGuide::Schema->Connect();

    my $sql = <<'EOF';
UPDATE VendorImage
   SET display_order = IF( display_order = ?, 1, display_order + 1 )
 WHERE vendor_id = ?
   AND display_order <= ?
EOF

    $schema->driver()->do( sql => $sql,
                           bind => [ $order, $self->vendor_id(), $order ] );
}

sub rest_data
{
    my $self = shift;

    return ( uri     => $self->large_uri(),
             caption => $self->caption(),
             height  => $self->large_height(),
             width   => $self->large_width(),
           );
}

sub AllVendorIds
{
    my $class = shift;

    return $class->table()->function( select => $class->table()->vendor_id_c() );
}



1;
