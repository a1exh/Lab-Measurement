package Lab::Moose::Connection::Debug;

#ABSTRACT: Debug connection

use Moose;
use 5.010;
use namespace::autoclean;
use Data::Dumper;
use YAML::XS;

use Carp;

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

sub Write {
    my $self = shift;
    my %args = @_;
    if ( $self->verbose() ) {
        carp "Write called with args:\n", Dump \%args, "\n";
    }
}

sub Read {
    my $self = shift;
    my %args = @_;
    carp "Read called with args:\n", Dump \%args, "\n";
    say "enter return value:";
    my $retval = <STDIN>;
    chomp $retval;
    return $retval;
}

sub Query {
    my $self = shift;
    my %args = @_;
    carp "Query called with args:\n", Dump \%args, "\n";
    say "enter return value:";
    my $retval = <STDIN>;
    chomp $retval;
    return $retval;
}

sub Clear {
    my $self = shift;
    if ( $self->verbose ) {
        carp "Clear called";
    }
}

with 'Lab::Moose::Connection';

__PACKAGE__->meta->make_immutable();
1;

=head1 SYNOPSIS

 use Lab::Moose;

 my $instrument = instrument(
     type => 'DummySource',
     connection_type => 'DEBUG'
     connection_options => {
         verbose => 0, # do not print arguments of all Write commands (default is 1).
     }
 );


=head1 DESCRIPTION

Debug connection object. Print out C<Write> commands and prompt answer for
C<Read> commands.

=cut
