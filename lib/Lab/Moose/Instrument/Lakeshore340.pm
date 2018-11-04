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
        channel => { isa => enum( [qw/A B/] ) }
    );
    my $channel = delete $args{channel} // $self->input_channel();
    return $self->query( command => "KRDG? $channel", %args );
}

sub get_value {
    my $self = shift;
    return $self->get_T(@_);
}

=head2 Consumed Roles

This driver consumes the following roles:

=over

=item L<Lab::Moose::Instrument::Common>

=back

=cut

__PACKAGE__->meta()->make_immutable();

1;
