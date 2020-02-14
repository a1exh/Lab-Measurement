package Lab::Moose::Instrument::Lakeshore340;

#ABSTRACT: Lakeshore Model 340 Temperature Controller

use 5.010;
use Moose;
use Moose::Util::TypeConstraints qw/enum/;
use MooseX::Params::Validate;
use Lab::Moose::Instrument qw/
    validated_getter validated_setter setter_params /;
use Lab::Moose::Instrument::Cache;
use Carp;
use namespace::autoclean;

#use POSIX qw/log10 ceil floor/;

extends 'Lab::Moose::Instrument';

with qw(
    Lab::Moose::Instrument::Common
);

has input_channel => (
    is      => 'ro',
    isa     => enum( [qw/A B/] ),
    default => 'A',
);

sub BUILD {
    my $self = shift;
    $self->clear();
    $self->cls();
}

my %channel_arg = ( channel => { isa => enum( [qw/A B/] ), optional => 1 } );
my %loop_arg = ( loop => { isa => enum( [qw/1 2/] ) } );

=encoding utf8

=head1 SYNOPSIS

 use Lab::Moose;

 # Constructor
 my $lakeshore = instrument(
     type => 'Lakeshore340',
     connection_type => 'LinuxGPIB',
     connection_options => {pad => 22},
     
     input_channel => 'B', # set default input channel for all method calls
 );

 my $temp_B = $lakeshore->get_T(); # Get temp for input 'B' set as default in constructor.

 my $temp_A = $lakeshore->get_T(channel => 'A'); # Get temp for input 'A'.

=head1 METHODS

=head2 get_T

my $temp = $lakeshore->get_T(channel => $channel);

C<$channel> can be 'A' or 'B'. The default can be set in the constructor.


=head2 get_value

alias for C<get_T>.

=cut

sub get_T {
    my ( $self, %args ) = validated_getter(
        \@_,
        %channel_arg
    );
    my $channel = delete $args{channel} // $self->input_channel();
    return $self->query( command => "KRDG? $channel", %args );
}

sub get_value {
    my $self = shift;
    return $self->get_T(@_);
}

=head2 set_setpoint/get_setpoint
 # set/get SP for loop 1 in whatever units the setpoint is using
 $lakeshore->set_setpoint(value => 10, loop => 1); 
 my $setpoint1 = $lakeshore->get_setpoint(loop => 1);
 
=cut

sub get_setpoint {
    my ( $self, %args ) = validated_getter(
        \@_,
        %loop_arg
    );
    my $loop = delete $args{loop};
    return $self->query( command => "SETP? $loop", %args );
}

sub set_setpoint {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        %loop_arg
    );
    my $loop = delete $args{loop};

    # Device bug. The 340 cannot parse values with too many digits.
    $value = sprintf( "%.6G", $value );
    $self->write( command => "SETP $loop,$value", %args );
}

=head2 set_T

alias for C<set_setpoint>

=cut

sub set_T {
    my $self = shift;
    $self->set_setpoint(@_);
}

=head2 set_heater_range/get_heater_range

 $lakeshore->set_heater_range(value => 1);
 my $range = $lakeshore->get_heater_range();

Value is one of 0 (OFF),1,...,5 (MAX)

=cut

sub set_heater_range {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/0 1 2 3 4 5/] ) }
    );
    $self->write( command => "RANGE $value", %args );
}

sub get_heater_range {
    my ( $self, %args ) = validated_getter( \@_ );
    return $self->query( command => "RANGE?", %args );
}

=head2 set_control_mode/get_control_mode

Specifies the control mode. Valid entries: 1 = Manual PID, 2 = Zone,
 3 = Open Loop 4 = AutoTune PID, 5 = AutoTune PI, 6 = AutoTune P.

 # Set loop 1 to manual PID
 $lakeshore->set_control_mode(value => 1, loop => 1);
 my $cmode = $lakeshore->get_control_mode(loop => 1);

=cut

sub set_control_mode {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [ ( 1 .. 6 ) ] ) },
        %loop_arg
    );
    my $loop = delete $args{loop};
    return $self->write( command => "CMODE $loop,$value", %args );
}

sub get_control_mode {
    my ( $self, %args ) = validated_getter(
        \@_,
        %loop_arg
    );
    my $loop = delete $args{loop};
    return $self->query( command => "CMODE? $loop", %args );
}

=head2 set_control_parameters/get_control_parameters

 $lakeshore->set_control_parameters(
    loop => 1,
    input => 'A',
    units => 1, # 1 = Kelvin, 2 = Celsius, 3 = sensor units
    state => 1, # 0 = off, 1 = on
    powerup_enable => 1, # 0 = off, 1 = on, optional with default = off
 );
 my %args = $lakeshore->get_control_parameters(loop => 1);

=cut

sub set_control_parameters {
    my ( $self, %args ) = validated_getter(
        \@_,
        %loop_arg,
        %channel_arg,
        units          => { isa => enum( [qw/1 2 3/] ) },
        state          => { isa => enum( [qw/0 1/] ) },
        powerup_enable => { isa => enum( [qw/0 1/] ), default => 1 },
    );
    my $loop           = delete $args{loop};
    my $channel        = delete $args{channel} // $self->input_channel();
    my $units          = delete $args{units};
    my $state          = delete $args{state};
    my $powerup_enable = delete $args{powerup_enable};
    $self->write( command => "CSET $loop, $channel, $units, $state,"
            . "$powerup_enable", %args );
}

sub get_control_parameters {
    my ( $self, %args ) = validated_getter(
        \@_,
        %loop_arg
    );
    my $loop = delete $args{loop};
    my $rv   = $self->query( command => "CSET? $loop", %args );
    my @rv   = split /,/, $rv;
    return (
        channel        => $rv[0], units => $rv[1], state => $rv[2],
        powerup_enable => $rv[3]
    );
}

=head2 set_input_curve/get_input_curve

 # Set channel 'B' to use curve 25
 $lakeshore->set_input_curve(channel => 'B', value => 25);
 my $curve = $lakeshore->get_input_curve(channel => 'B');

=cut

sub set_input_curve {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        %channel_arg,
        value => { isa => enum( [ 0 .. 60 ] ) },
    );
    my $channel = delete $args{channel} // $self->input_channel();
    $self->write( command => "INCRV $channel,$value", %args );
}

sub get_input_curve {
    my ( $self, %args ) = validated_getter(
        \@_,
        %channel_arg,
    );
    my $channel = delete $args{channel} // $self->input_channel();
    return $self->query( command => "INCRV $channel", %args );
}

=head2 Consumed Roles

This driver consumes the following roles:

=over

=item L<Lab::Moose::Instrument::Common>

=back

=cut

__PACKAGE__->meta()->make_immutable();

1;
