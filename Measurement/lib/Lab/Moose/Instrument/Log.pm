package Lab::Moose::Instrument::Log;
use Moose::Role;
use Carp;
use namespace::autoclean;
use YAML::XS;
use IO::Handle;

our $VERSION = '3.520';

has log_file => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_log_file',
);

has log_fh => (
    is        => 'ro',
    isa       => 'FileHandle',
    builder   => 'log_build_fh',
    predicate => 'has_log_fh',
    lazy      => 1,
);

has log_id => (
    is      => 'ro',
    isa     => 'Int',
    writer  => '_log_id',
    default => 0,
);

sub log_build_fh {
    my $self = shift;
    my $file = $self->log_file();
    open my $fh, '>', $file
        or croak "cannot open logfile '$file': $!";
    $fh->autoflush();
    return $fh;
}

for my $method (qw/read write query clear/) {
    around $method => sub {
        my $orig   = shift;
        my $self   = shift;
        my @params = @_;

        if ( !( $self->has_log_fh() || $self->has_log_file() ) ) {
            return $self->$orig(@params);
        }

        my %arg;
        if ( ref $params[0] eq 'HASH' ) {
            %arg = %{ $params[0] };
        }
        else {
            %arg = @params;
        }

        my $retval = $self->$orig(@params);

        if ( $retval !~ /[^[:ascii:]]/ ) {
            $arg{retval} = $retval;
        }
        else {
            $arg{retval_enc} = 'hex';
            $arg{retval} = unpack( 'H*', $retval );
        }

        $arg{method} = ucfirst $method;

        my $id = $self->log_id();
        $arg{id} = $id;
        $self->_log_id( ++$id );

        my $fh = $self->log_fh();
        print {$fh} Dump( \%arg );

        return $retval;
        }
}

1;
