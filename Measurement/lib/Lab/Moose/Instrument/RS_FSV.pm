package Lab::Moose::Instrument::RS_FSV;

use 5.010;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Params::Validate;
use Lab::Moose::Instrument qw/timeout_param precision_param/;
use Lab::Moose::BlockData;
use Carp;
use namespace::autoclean;

our $VERSION = '3.530';

extends 'Lab::Moose::Instrument';

with qw(
    Lab::Moose::Instrument::Common

    Lab::Moose::Instrument::SCPI::Format

    Lab::Moose::Instrument::SCPI::Sense::Frequency
    Lab::Moose::Instrument::SCPI::Sense::Sweep

    Lab::Moose::Instrument::SCPI::Initiate

    Lab::Moose::Instrument::SCPIBlock

);

sub BUILD {
    my $self = shift;
    $self->clear();
    $self->cls();
}

=head1 NAME

Lab::Moose::Instrument::RS_FSV - Rohde & Schwarz FSV Signal and Spectrum
Analyzer

=head1 SYNOPSIS

 my $data = $fsv->get_spectrum(timeout => 10);
 my $matrix = $data->matrix;

=cut

=head1 METHODS

This driver implements the following high-level method:

=head2 get_spectrum

 $data = $fsv->get_spectrum(timeout => 10, trace => 2, precision => 'double');

Perform a single sweep and return the resulting spectrum. The result is an
instance of L<Lab::Moose::BlockData>. For each sweep point, one row of data
[frequency, power] will be returned.

This method accepts a hash with the following options:

=over

=item B<timeout>

timeout for the sweep operation. If this is not given, use the connection's
default timeout.

=item B<trace>

number of the trace (1..6). Defaults to 1.

=item B<precision>

floating point type. Has to be 'single' or 'double'. Defaults to 'single'.

=back

=cut

sub get_spectrum {
    my ( $self, %args ) = validated_hash(
        \@_,
        timeout_param(),
        precision_param(),
        trace => { isa => 'Int', default => 1 },
    );

    my $precision = delete $args{precision};

    my $trace = delete $args{trace};

    if ( $trace < 1 || $trace > 6 ) {
        croak "trace has to be in (1..6)";
    }

    my $freq_array = $self->sense_frequency_linear_array();

    # Ensure single sweep mode.
    if ( $self->cached_initiate_continuous() ) {
        $self->initiate_continuous( value => 0 );
    }

    # Ensure correct data format
    $self->set_data_format_precision( precision => $precision );

    # Get data.

    $self->initiate_immediate();
    $self->wai();

    my $binary = $self->binary_query(
        command => "TRAC? TRACE$trace",
        %args
    );

    my $points_ref = $self->block_to_array(
        binary    => $binary,
        precision => $precision
    );

    my $result = Lab::Moose::BlockData->new();
    $result->add_column($freq_array);
    $result->add_column($points_ref);

    return $result;
}

=head2 Consumed Roles

This driver consumes the following roles:

=over

=item L<Lab::Moose::Instrument::Common>

=item L<Lab::Moose::Instrument::SCPI::Format>

=item L<Lab::Moose::Instrument::SCPI::Sense::Frequency>

=item L<Lab::Moose::Instrument::SCPI::Sense::Sweep>

=item L<Lab::Moose::Instrument::SCPI::Initiate>

=item L<Lab::Moose::Instrument::SCPIBlock>

=back

=cut

1;
