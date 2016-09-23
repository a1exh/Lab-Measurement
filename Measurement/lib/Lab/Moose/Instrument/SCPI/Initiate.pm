package Lab::Moose::Instrument::SCPI::Initiate;
use Moose::Role;
use Lab::Moose::Instrument
    qw/validated_no_param_setter validated_setter validated_getter/;
use Lab::Moose::Instrument::Cache;
use MooseX::Params::Validate;

our $VERSION = '3.520';

cache initiate_continuous => ( getter => 'initiate_continuous_query' );

sub initiate_continuous {
    my ( $self, %args )
        = validated_no_param_setter( \@_, value => { isa => 'Bool' } );

    my $value = delete $args{value};
    $value = $value ? 1 : 0;

    $self->write( command => "INIT:CONT $value", %args );
    $self->cached_initiate_continuous($value);
}

sub initiate_continuous_query {
    my ( $self, %args ) = validated_getter( \@_ );

    return $self->cached_initiate_continuous(
        $self->query( command => 'INIT:CONT?', %args ) );
}

sub initiate_immediate {
    my ( $self, %args ) = validated_no_param_setter( \@_ );
    $self->write( command => 'INIT', %args );
}

1;
