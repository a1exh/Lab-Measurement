package Lab::Moose::Connection::Socket;

#ABSTRACT: Transfer IEEE 488.2 / SCPI messages over TCP

use 5.010;

use Moose;
use MooseX::Params::Validate;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use IO::Socket::INET;
use IO::Socket::Timeout;
use Carp;

use Lab::Moose::Instrument qw/timeout_param read_length_param/;

use namespace::autoclean;

has client => (
    is       => 'ro',
    isa      => 'IO::Socket::INET',
    writer   => '_client',
    init_arg => undef,
);

has host => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has port => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has write_termchar => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    default => "\n",
);

sub BUILD {
    my $self    = shift;
    my $host    = $self->host();
    my $port    = $self->port();
    my $timeout = $self->timeout();
    my $client  = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => $timeout,
    ) or croak "cannot open connection with $host on port $port: $!";

    IO::Socket::Timeout->enable_timeouts_on($client);
    $client->read_timeout($timeout);
    $client->write_timeout($timeout);

    $client->setsockopt( IPPROTO_TCP, TCP_NODELAY, 1 )
        or die "setsockopt: cannot enable TCP_NODELAY";
    $self->_client($client);
}

sub Write {
    my ( $self, %arg ) = validated_hash(
        \@_,
        timeout_param,
        command => { isa => 'Str' },
    );

    my $write_termchar = $self->write_termchar() // '';
    my $command        = $arg{command} . $write_termchar;
    my $timeout        = $self->_timeout_arg(%arg);

    my $client = $self->client();
    $client->write_timeout($timeout);

    print {$client} $command
        or croak "socket write error: $!";
}

sub Read {
    my ( $self, %arg ) = validated_hash(
        \@_,
        timeout_param(),
        read_length_param(),
    );
    my $timeout     = $self->_timeout_arg(%arg);
    my $read_length = $self->_read_length_arg(%arg);
    my $client      = $self->client();

    $client->read_timeout($timeout);

    my $string;
    my $read_bytes = read( $client, $string, $read_length );
    if ( !$read_bytes ) {
        croak "socket read error: $!";
    }

    return $string;
}

sub Clear {

    # Some instruments provide an additional control port.
}

with qw/
    Lab::Moose::Connection
    /;

__PACKAGE__->meta->make_immutable();

1;

=head1 SYNOPSIS

 use Lab::Moose;

 my $instrument = instrument(
     type => 'random_instrument',
     connection_type => 'Socket',
     connection_options => {
         host => '132.199.11.2',
         port => 5025
     },
 );

=head1 DESCRIPTION

This connection uses L<IO::Socket::INET> to interface with the operating
system's TCP stack. This works on most operating systems without installing any
additional software.

=head2 CONNECTION OPTIONS

=over

=item host

Host address.

=item port

Host port.

=item write_termchar

Append this to each write command. Default: C<"\n">.

=back

=cut

