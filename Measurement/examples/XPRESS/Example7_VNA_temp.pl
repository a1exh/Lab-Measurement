#!/usr/bin/perl

use warnings;
use strict;
use 5.010;

#-------- 0. Import Lab::Measurement -------

use Lab::Measurement;

#-------- 1. Initialize Instruments --------

# the dilution control

my $dilfridge = Instrument(
    'OI_Triton',
    { connection_type => 'Socket' }
);
$dilfridge->enable_control();

# the network analyzer

use aliased 'Lab::Moose::Instrument::RS_ZVA' => 'VNA';

# RS_ZVA needs the Moose version of the LinuxGPIB connection.
use aliased 'Lab::Moose::Connection::LinuxGPIB' => 'Moose::GPIB';

# Construct instruments and connections.
my $vna = VNA->new( connection => Moose::GPIB->new( pad => 20 ) );

#-------- 2. Define the Sweeps -------------

my $temperature_sweep = Sweep(
    'Temperature',
    {
        mode       => 'step',
        instrument => $dilfridge,
        points     => [ 25e-3, 40e-3 ],    # [starting point, target] in K
        stepwidth  => 5e-3,                # step width in K
        tolerance_setpoint => 0.003
        , # absolute tolerance (in Kelvin) for temperature before waiting time
        std_dev_instrument =>
            0.003,    # allowed standard deviation (in Kelvin) for same
        stabilize_observation_time => 10
            * 60,     # time that temperature has to be stable
        delay_in_loop => 20
            * 60,   # additional waiting time for sample to thermalize with mc
        stabilize_measurement_interval => 10,    # temperature read out period
    }
);

#-------- 3. Create a DataFile -------------

my $DataFile = DataFile('tempcurve.dat');

$DataFile->add_column('Temperature');
$DataFile->add_column('Frequency');

# Get names of the configured S-parameter real/imag parts.
my @sparams = @{ $vna->sparam_catalog() };

for my $sparam (@sparams) {
    $DataFile->add_column($sparam);
}

#-------- 4. Measurement Instructions -------

my $my_measurement = sub {

    my $sweep = shift;

    my $temperature = $dilfridge->get_value();

    my $data = $vna->sparam_sweep( timeout => 30 );

    $sweep->LogBlock(
        prefix => [$temperature],
        block  => $data->matrix(),
    );

};

#-------- 5. Put everything together -------

$DataFile->add_measurement($my_measurement);

$temperature_sweep->add_DataFile($DataFile);

$temperature_sweep->start();

$dilfridge->disable_control();

1;

=pod

=encoding utf-8

=head1 Name

XPRESS for DUMMIES

=cut
