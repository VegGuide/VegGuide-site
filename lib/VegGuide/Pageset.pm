package VegGuide::Pageset;

use parent 'Data::Pageset';

sub is_current_page { return $_[0]->current_page() == $_[1] }

1;
