package Lab::Connection::USBtmc::Trace;
use 5.010;
use warnings;
use strict;

use parent 'Lab::Connection::USBtmc';

use Role::Tiny::With;
use Carp;
use autodie;

our $VERSION = '3.544';

our %fields = (
    logfile   => undef,
    log_index => 0,
);

with 'Lab::Connection::Trace';

1;

