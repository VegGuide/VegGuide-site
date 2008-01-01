package VegGuide::Skin;

use strict;
use warnings;

use VegGuide::AlzaboWrapper ( table => VegGuide::Schema->Schema->Skin_t );

use File::Basename ();
use VegGuide::Exceptions qw( auth_error data_validation_error );
use File::Basename qw( dirname );
use File::Copy qw( copy );
use File::Path qw( mkpath );
use File::Spec;
use URI::FromHash qw( uri );
use VegGuide::Config;
use VegGuide::Location;
use VegGuide::Util;

use VegGuide::Validate qw( validate validate_pos SCALAR );


sub _new_row
{
    my $class = shift;
    my %p = validate( @_, { hostname => { type => SCALAR },
                          },
                    );

    my $schema = VegGuide::Schema->Connect();

    return
        $schema->Skin_t->one_row
            ( where =>
              [ $schema->Skin_t->hostname_c, '=', $p{hostname} ]
            );
}

sub create
{
    my $class = shift;

    my %p = @_;

    $class->_convert_empty_strings(\%p);

    return $class->SUPER::create(%p);
}

sub update
{
    my $self = shift;

    my %p = @_;

    $self->_convert_empty_strings(\%p);

    $self->SUPER::update(%p);
}

{
    my %char_cols =
        map { $_->name => 1 }
        grep { $_->is_character || $_->is_blob }
        __PACKAGE__->columns;

    my %num_cols =
        map { $_->name => 1 }
        grep { $_->is_numeric }
        __PACKAGE__->columns;

    sub _convert_empty_strings
    {
        shift;

        VegGuide::Util::convert_empty_strings( shift, \%char_cols, \%num_cols );
    }
}

sub home_location
{
    my $self = shift;

    return unless $self->home_location_id();

    return VegGuide::Location->new( location_id => $self->home_location_id() );
}

sub root_uri
{
    my $self = shift;

    my $host =
        VegGuide::Config->IsProduction()
        ? $self->hostname() . '.vegguide.org'
        : VegGuide::Config->CanonicalWebHostname();

    my %query;
    %query = ( skin_id => $self->skin_id() )
        unless VegGuide::Config->IsProduction();

    return uri( scheme => 'http',
                host   => $host,
                query  => \%query,
              );
}

sub SkinForHostname
{
    my $class = shift;
    my $hostname = shift;

    $hostname =~ s/\.vegguide\.org$//;

    my $skin;
    $skin = $class->new( hostname => $hostname );

    return $skin if $skin;

    return $class->new( hostname => 'www' );
}

sub All
{
    my $class = shift;
    my %p = validate( @_,
                      { order_by => { type => SCALAR, default => 'hostname' } },
                    );

    my $schema = VegGuide::Schema->Connect();

    return
        $class->cursor
            ( $schema->Skin_t->all_rows
                  ( order_by => $schema->Skin_t->column( $p{order_by} ) )
            );
}

{
    my $Height = 65;
    my $Width  = 100;

    sub save_image
    {
        my $self = shift;
        my $fh   = shift;

        my $img = Image::Magick->new;
        $img->read( file => $fh );

        my $i_height = $img->get('height');
        my $i_width  = $img->get('width');

        if ( $Height < $i_height
             ||
             $Width  < $i_width
           )
        {
            my $height_r = $Height / $i_height;
            my $width_r  = $Width / $i_width;

            my $ratio = $height_r < $width_r ? $height_r : $width_r;

            $img->Scale( height => int( $i_height * $ratio ),
                         width  => int( $i_width * $ratio ),
                       );
        }

        my $path = $self->custom_image_file_path();
        mkpath( dirname( $path ), 0, 0755 );

        $img->write( filename => $path,
                     quality  => $img->get('quality'),
                     type     => 'Palette',
                   );
    }

    sub Dimensions
    {
        return { height => $Height, width => $Width };
    }
}

sub custom_image_file_path
{
    my $self = shift;

    return
        File::Spec->canonpath
            ( File::Spec->catfile( VegGuide::Config->VarLibDir(),
                                   'skin-images', $self->hostname . '.png' ) );
}

{
    my $DefaultLogoURI ='/images/vegguide-logo.png';

    sub image_uri
    {
        my $self = shift;

        return $DefaultLogoURI unless $self->has_custom_image;

        my $doc_root = VegGuide::Config->VarLibDir();

        my $file = $self->custom_image_file_path;
        $file =~ s/^\Q$doc_root\E//;

        return $file;
    }

    sub image_file
    {
        my $self = shift;

        my $uri = $self->image_uri();

        return $uri eq $DefaultLogoURI
               ? File::Spec->catfile( VegGuide::Config->ShareDir(), $uri )
               : File::Spec->catfile( VegGuide::Config->VarLibDir(), $uri );
    }
}

sub has_custom_image { -e $_[0]->custom_image_file_path }


1;
