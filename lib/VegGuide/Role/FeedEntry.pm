package VegGuide::Role::FeedEntry;

use strict;
use warnings;

use Class::Trait 'base';

our @REQUIRES = qw( creation_datetime_object feed_title feed_uri feed_template_params );

use HTML::Mason::Interp;
use VegGuide::Config;
use VegGuide::Util;
use XML::Feed::Entry;


{
    my $Interp =
        HTML::Mason::Interp->new
            ( comp_root => File::Spec->catdir( VegGuide::Config->ShareDir(), 'feed-templates' ),
              data_dir  => File::Spec->catdir( VegGuide::Config->CacheDir(), 'mason', 'feeds' ),
              error_mode => 'fatal',
              in_package => 'VegGuide::Mason::Feed',
            );

    VegGuide::Util::chown_files_for_server( $Interp->files_written() );

    sub as_xml_feed_entry
    {
        my $self = shift;

        my $entry = XML::Feed::Entry->new();
        $entry->title( $self->feed_title() );
        $entry->link( $self->feed_uri()  );
        $entry->id( $entry->link() );
        $entry->issued( $self->creation_datetime_object() );
        $entry->modified( $self->creation_datetime_object() );
        $entry->author( $self->user()->real_name() );

        my $content;
        $Interp->out_method( \$content );

        $Interp->exec( $self->feed_template_params() );

        $entry->content($content);

        return $entry;
    }
}


1;
