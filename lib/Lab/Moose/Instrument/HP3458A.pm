package Lab::Moose::Instrument::HP3458A;

#ABSTRACT: HP 3458A digital multimeter

use 5.010;
use Moose;
use Moose::Util::TypeConstraints qw/enum/;
use MooseX::Params::Validate;
use Lab::Moose::Instrument qw/
    validated_getter validated_setter setter_params /;
use Lab::Moose::Instrument::Cache;
use Carp;
use namespace::autoclean;

extends 'Lab::Moose::Instrument';

with qw(
    Lab::Moose::Instrument::Common
);

sub BUILD {
    my $self = shift;
    $self->clear();    # FIXME: does this change any settings!
    $self->set_end(value => 'ALWAYS');
}

=encoding utf8

=head1 SYNOPSIS

 use Lab::Moose;


=head1 METHODS


=cut

sub get_value {
    my ( $self, %args ) = validated_hash(
        \@_,
        setter_params(),
    );
    return $self->read(%args);
}

cache nrdgs        => ( getter => 'get_nrdgs' );
cache sample_event => ( getter => 'get_sample_event' );

sub get_nrdgs {
    my ( $self, %args ) = validated_getter( \@_ );
    my $result = $self->query( command => "NRDGS?", %args );
    my ( $points, $event ) = split( /,/, $result );
    $self->cached_nrdgs($points);
    $self->cached_sample_event($event);
    return $points;
}

sub get_sample_event {
    my ( $self, %args ) = validated_getter( \@_ );
    my $result = $self->query( command => "NRDGS?", %args );
    my ( $points, $event ) = split( /,/, $result );
    $self->cached_nrdgs($points);
    $self->cached_sample_event($event);
    return $event;
}

sub set_nrdgs {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => 'Int' },
    );
    my $sample_event = $self->cached_sample_event();
    $self->write( command => "NRDGS $value,$sample_event", %args );
    $self->cached_nrdgs($value);
}

sub set_sample_event {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/AUTO EXTSYN SYN TIMER LEVEL LINE/] ) },
    );
    my $points = $self->cached_nrdgs();
    $self->write( command => "NRDGS $points,$value", %args );
    $self->cached_sample_event($value);
}

cache tarm_event => ( getter => 'get_tarm_event' );

sub get_tarm_event {
    my ( $self, %args ) = validated_getter( \@_ );
    return $self->cached_tarm_event(
        $self->query( command => "TARM?", %args ) );
}

sub set_tarm_event {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/AUTO EXT SGL HOLD SYN/] ) },
    );
    $self->write( command => "TARM $value", %args );
    $self->cached_tarm_event($value);
}

cache trig_event => ( getter => 'get_trig_event' );

sub get_trig_event {
    my ( $self, %args ) = validated_getter( \@_ );
    return $self->cached_trig_event(
        $self->query( command => "TRIG?", %args ) );
}

sub set_trig_event {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
        value => { isa => enum( [qw/AUTO EXT SGL HOLD SYN LEVEL LINE/] ) },
    );
    $self->write( command => "TRIG $value", %args );
    $self->cached_trig_event($value);
}

cache end => (getter => 'get_end');

sub get_end {
    my ($self, %args) = validated_getter(\@_);
    return $self->cached_end(
	$self->query(command => "END?", %args));
}

sub set_end {
    my ($self, $value, %args) = validated_setter(
	\@_,
	value => {isa => enum([qw/OFF ON ALWAYS/])}
	);
    $self->write(command => "END $value");
    $self->cached_trig_event($value);
}

cache nplc => (getter => 'get_nplc');

sub get_nplc {
    my ($self, %args) = validated_getter(\@_);
    return $self->cached_nplc(
	$self->query(command => "NPLC?", %args));
}

sub set_nplc {
    my ($self, $value, %args) = validated_setter(
	\@_,
	value => {isa => 'Num'});
    $self->write(command => "NPLC $value", %args);
    $self->cached_nplc($value);
}
	
=head2 Consumed Roles

This driver consumes the following roles:

=over

=item L<Lab::Moose::Instrument::Common>

=back

=cut

__PACKAGE__->meta()->make_immutable();

1;
