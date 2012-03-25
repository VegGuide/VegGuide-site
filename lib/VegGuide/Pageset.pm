package VegGuide::Pageset;

use parent 'Data::Pageset';

use Scalar::Util qw( weaken );

sub is_current_page { return $_[0]->current_page() == $_[1] }

1;
