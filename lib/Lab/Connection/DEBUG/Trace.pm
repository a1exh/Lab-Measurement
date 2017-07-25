package Lab::Connection::DEBUG::Trace;
#ABSTRACT: ???

use 5.010;
use warnings;
use strict;

use parent 'Lab::Connection::DEBUG';

use Role::Tiny::With;
use Carp;
use autodie;

our %fields = (
    logfile   => undef,
    log_index => 0,
);

with 'Lab::Connection::Trace';

1;

