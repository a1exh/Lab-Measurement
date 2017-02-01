package Lab::Moose::Instrument::SR830;

use 5.010;
use Moose;
use Moose::Util::TypeConstraints qw/enum/;
use MooseX::Params::Validate;
use Lab::Moose::Instrument qw/
    validated_getter validated_setter setter_params /;
use Lab::Moose::Instrument::Cache;
use Carp;
use namespace::autoclean;
use POSIX qw/log10 ceil floor/;

our $VERSION = '3.540';

extends 'Lab::Moose::Instrument';

with qw(
    Lab::Moose::Instrument::Common
);

sub BUILD {
    my $self = shift;
    $self->clear();
    $self->cls();
}

=encoding utf8

=head1 NAME

Lab::Moose::Instrument::SR830 -  Stanford Research SR830 Lock-In Amplifier

=head1 SYNOPSIS

 use Lab::Moose;

 # Constructor
 my $lia = instrument(type => 'SR830', %connection_options);
 
 # Set reference frequency to 10 kHz
 $lia->set_freq(value => 10000);

 # Set time constant to 10 sec
 $lia->set_tc(value => 10);

 # Set sensitivity to 10 mV
 $lia->set_sens(value => 0.001);
 
 # Get X and Y values
 my $xy = $lia->get_xy();
 say "X: ", $xy->{x};
 say "Y: ", $xy->{y};

=head1 METHODS

=head2 get_freq

 my $freq = $lia->get_freq();

Query frequency of the reference oscillator.

=head2 set_freq

 $lia->set_freq(value => $freq);

Set frequency of the reference oscillator.

=cut

cache freq => ( getter => 'get_freq' );

sub get_freq {
    my ( $self, %args ) = validated_getter( \@_ );
    return $self->cached_freq( $self->query( command => 'FREQ?', %args ) );
}

sub set_freq {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => 'Num' }
    );

    $self->write( command => "FREQ $value", %args );
    $self->cached_freq($value);
}

=head2 get_amplitude

 my $ampl = $lia->get_amplitude();

Query amplitude of the sine output.

=head2 set_amplitude

 $lia->set_amplitude(value => $ampl);

Set amplitude of the sine output.

=cut

cache amplitude => ( getter => 'get_amplitude' );

sub get_amplitude {
    my ( $self, %args ) = validated_getter( \@_ );
    return $self->cached_amplitude(
        $self->query( command => 'SLVL?', %args ) );
}

sub set_amplitude {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => 'Num' }
    );
    $self->write( command => "SLVL $value", %args );
    $self->cached_amplitude($value);
}

cache phase => ( getter => 'get_phase' );

=head2 get_phase

 my $phase = $lia->get_phase();

Get reference phase shift (in degree). Result is between -180 and 180.

=head2 set_phase

 $lia->set_phase(value => $phase);

Set reference phase shift. The C<$phase> parameter has to be between -360 and
729.99.

=cut

sub get_phase {
    my ( $self, %args ) = validated_getter( \@_ );
    return $self->cached_phase( $self->query( command => 'PHAS?', %args ) );
}

sub set_phase {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => 'Num' }
    );

    if ( $value < -360 || $value > 729.98 ) {
        croak "$value is not in allowed range of phase: [-360, 729.99] deg.";
    }
    $self->write( command => "PHAS $value", %args );
    $self->cached_phase($value);
}

=head2 get_xy

 my $xy = $lia->get_xy();
 my $x = $xy->{x};
 my $y = $xy->{y};

Query the X and Y values.

=head2 get_rphi

 my $rphi = $lia->get_rphi();
 my $r = $rphi->{r};
 my $phi = $rphi->{phi};

Query R and the angle (in degree).

=head2 get_xyrphi

Get x, y, R and the angle all in one call.

=cut

cache xy => ( getter => 'get_xy' );

sub get_xy {
    my ( $self, %args ) = validated_getter( \@_ );
    my $retval = $self->query( command => "SNAP?1,2", %args );
    my ( $x, $y ) = split( ',', $retval );
    chomp $y;
    return $self->cached_xy( { x => $x, y => $y } );
}

cache rphi => ( getter => 'get_rphi' );

sub get_rphi {
    my ( $self, %args ) = validated_getter( \@_ );
    my $retval = $self->query( command => "SNAP?3,4", %args );
    my ( $r, $phi ) = split( ',', $retval );
    chomp $phi;
    return $self->cached_rphi( { r => $r, phi => $phi } );
}

cache xyrphi => ( getter => 'get_xyrphi' );

sub get_xyrphi {
    my ( $self, %args ) = validated_getter( \@_ );
    my $retval = $self->query( command => "SNAP?1,2,3,4", %args );
    my ( $x, $y, $r, $phi ) = split( ',', $retval );
    chomp( $x, $y, $r, $phi );
    return $self->cached_xyrphi( { x => $x, y => $y, r => $r, phi => $phi } );
}

cache tc => ( getter => 'get_tc' );

=head2 get_tc

 my $tc = $lia->get_tc();

Query the time constant.

=head2 set_tc

 # Set tc to 30μs
 $lia->set_tc(value => 30e-6);

Set the time constant. The value is rounded to the nearest valid
value. Rounding is performed in logscale. Croak if the the value is out of
range.

=cut

sub _int_to_tc {
    my $self = shift;
    my ($int_tc) = pos_validated_list( \@_, { isa => 'Int' } );
    use integer;
    my $exponent = $int_tc / 2 - 5;
    no integer;

    my $tc = 10**($exponent);

    if ( $int_tc % 2 ) {
        $tc *= 3;
    }
    return $tc;
}

sub get_tc {
    my ( $self, %args ) = validated_getter( \@_ );
    my $int_tc = $self->query( command => 'OFLT?', %args );
    return $self->cached_tc( $self->_int_to_tc($int_tc) );
}

sub set_tc {
    my ( $self, $tc, %args ) = validated_setter(
        \@_,
        value => { isa => 'Num' }
    );

    my $logval = log10($tc);
    my $n      = floor($logval);
    my $rest   = $logval - $n;
    my $int_tc = 2 * $n + 10;

    if ( $rest > log10(6.5) ) {
        $int_tc += 2;
    }
    elsif ( $rest > log10(2) ) {
        $int_tc += 1;
    }

    if ( $int_tc < 0 ) {
        croak "minimum value for time constant is 1e-5";
    }
    if ( $int_tc > 19 ) {
        croak "maximum value for time constant is 30000";
    }

    $self->write( command => "OFLT $int_tc", %args );
    $self->cached_tc( $self->_int_to_tc($int_tc) );
}

=head2 get_filter_slope

 my $filter_slope = $lia->get_filter_slope();

Query the low pass filter slope (dB/oct). Possible return values:

=over

=item * 6

=item * 12

=item * 18

=item * 24

=back

=head2 set_filter_slope

 $lia->set_filter_slope(value => 18);

Set the low pass filter slope (dB/oct). Allowed values:

=over

=item * 6

=item * 12

=item * 18

=item * 24

=back

=cut

cache filter_slope => ( getter => 'get_filter_slope' );

sub get_filter_slope {
    my ( $self, %args ) = validated_getter( \@_ );
    my $filter_slope = $self->query( command => 'OFSL?', %args );

    my %filter_slopes = ( 0 => 6, 1 => 12, 2 => 18, 3 => 24 );

    return $self->cached_filter_slope( $filter_slopes{$filter_slope} );
}

sub set_filter_slope {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/6 12 18 24/] ) }
    );
    my %filter_slopes = ( 6 => 0, 12 => 1, 18 => 2, 24 => 3 );
    my $filter_slope = $filter_slopes{$value};
    $self->write( command => "OFSL $filter_slope", %args );
    $self->cached_filter_slope($value);
}

=head2 get_sens

 my $sens = $lia->get_sens();

Get sensitivity (in Volt).

=head2 set_sens

 $lia->set_sens(value => $sens);

Set sensitivity (in Volt).

Same rounding as for C<set_tc>.

=cut

sub _int_to_sens {
    my $self = shift;
    my ($int_sens) = pos_validated_list( \@_, { isa => 'Int' } );

    ++$int_sens;

    use integer;
    my $exponent = $int_sens / 3 - 9;
    no integer;

    my $sens = 10**($exponent);

    if ( $int_sens % 3 == 1 ) {
        $sens *= 2;
    }
    elsif ( $int_sens % 3 == 2 ) {
        $sens *= 5;
    }

    return $sens;
}

cache sens => ( getter => 'get_sens' );

sub get_sens {
    my ( $self, %args ) = validated_getter( \@_ );
    my $int_sens = $self->query( command => 'SENS?', %args );
    return $self->cached_sens( $self->_int_to_sens($int_sens) );
}

sub set_sens {
    my ( $self, $sens, %args ) = validated_setter(
        \@_,
        value => { isa => 'Num' }
    );

    my $logval   = log10($sens);
    my $n        = floor($logval);
    my $rest     = $logval - $n;
    my $int_sens = 3 * $n + 26;

    if ( $rest > log10(7.5) ) {
        $int_sens += 3;
    }
    elsif ( $rest > log10(3.5) ) {
        $int_sens += 2;
    }
    elsif ( $rest > log10(1.5) ) {
        $int_sens += 1;
    }

    if ( $int_sens < 0 ) {
        croak "minimum value for sensitivity is 2nV";
    }

    if ( $int_sens > 26 ) {
        croak "maximum value for sensitivity is 1V";
    }

    $self->write( command => "SENS $int_sens", %args );
    $self->cached_sens( $self->_int_to_sens($int_sens) );
}

=head2 get_input

 my $input = $lia->get_input();

Query the input configuration. Possible return values:

=over

=item * A

=item * AB

=item * I1M

=item * I100M

=back

=head2 set_input

 $lia->set_input(value => 'AB');

Set input configuration. Allowed values:

=over

=item * A

=item * AB

=item * I1M

=item * I100M

=back

=cut

cache input => ( getter => 'get_input' );

sub get_input {
    my ( $self, %args ) = validated_getter( \@_ );
    my $input = $self->query( command => 'ISRC?', %args );

    my %inputs = ( 0 => 'A', 1 => 'AB', 2 => 'I1M', 3 => 'I100M' );

    return $self->cached_input( $inputs{$input} );
}

sub set_input {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/A AB I1M I100M/] ) }
    );
    my %inputs = ( A => 0, AB => 1, I1M => 2, I100M => 3 );
    my $input = $inputs{$value};
    $self->write( command => "ISRC $input", %args );
    $self->cached_input($value);
}

=head2 get_ground

 my $ground = $lia->get_ground();

Query the input shield grounding. Possible return values:

=over

=item * GROUND

=item * FLOAT

=back

=head2 set_ground

 $lia->set_ground(value => 'GROUND');

 # or:
 $lia->set_ground(value => 'FLOAT');

Set the input shield grounding. Allowed values:

=over

=item * GROUND

=item * FLOAT

=back

=cut

cache ground => ( getter => 'get_ground' );

sub get_ground {
    my ( $self, %args ) = validated_hash( \@_ );

    my $ground = $self->query( command => 'IGND?', %args );

    return $self->cached_ground( $ground ? 'GROUND' : 'FLOAT' );
}

sub set_ground {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/GROUND FLOAT/] ) }
    );
    my $ground = $value eq 'GROUND' ? 1 : 0;
    $self->write( command => "IGND $ground", %args );
    $self->cached_ground($value);
}

=head2 get_coupling

 my $coupling = $lia->get_coupling();

Query the input coupling. Possible return values:

=over

=item * AC

=item * DC

=back

=head2 set_coupling

 $lia->set_coupling(value => 'AC');

 # or:
 $lia->set_coupling(value => 'DC');

Set the input coupling. Allowed values:

=over

=item * AC

=item * DC

=back

=cut

cache coupling => ( getter => 'get_coupling' );

sub get_coupling {
    my ( $self, %args ) = validated_hash( \@_ );

    my $coupling = $self->query( command => 'ICPL?', %args );

    return $self->cached_coupling( $coupling ? 'DC' : 'AC' );
}

sub set_coupling {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/AC DC/] ) }
    );
    my $coupling = $value eq 'DC' ? 1 : 0;
    $self->write( command => "ICPL $coupling", %args );
    $self->cached_coupling($value);
}

=head2 get_line_notch_filters

 my $filters = $lia->get_line_notch_filters();

Query the line notch filter configuration. Possible return values:

=over

=item * OUT

=item * LINE

=item * 2xLINE

=item * BOTH

=back

=head2 set_line_notch_filters

 $lia->set_line_notch_filters(value => 'BOTH');

Set the line notch filter configuration. Allowed values:

=over

=item * OUT

=item * LINE

=item * 2xLINE

=item * BOTH

=back

=cut

cache line_notch_filters => ( getter => 'get_line_notch_filters' );

sub get_line_notch_filters {
    my ( $self, %args ) = validated_getter( \@_ );
    my $filters = $self->query( command => 'ILIN?', %args );

    my %filters = ( 0 => 'OUT', 1 => 'LINE', 2 => '2xLINE', 3 => 'BOTH' );

    return $self->cached_line_notch_filters( $filters{$filters} );
}

sub set_line_notch_filters {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/OUT LINE 2xLINE BOTH/] ) }
    );
    my %filters = ( OUT => 0, LINE => 1, '2xLINE' => 2, BOTH => 3 );
    my $filters = $filters{$value};
    $self->write( command => "ILIN $filters", %args );
    $self->cached_line_notch_filters($value);
}

=head2 Consumed Roles

This driver consumes the following roles:

=over

=item L<Lab::Moose::Instrument::Common>

=back

=cut

__PACKAGE__->meta()->make_immutable();

1;
