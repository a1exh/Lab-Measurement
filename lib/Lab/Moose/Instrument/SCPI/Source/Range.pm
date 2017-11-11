package Lab::Moose::Instrument::SCPI::Source::Range;

#ABSTRACT: Role for the SCPI SOURce:RANGe subsystem.

use Moose::Role;
use Moose::Util::TypeConstraints 'enum';
use Lab::Moose::Instrument::Cache;
use Lab::Moose::Instrument qw/validated_getter validated_setter/;

use namespace::autoclean;

=head1 METHODS

=head2 source_range_query

=head2 source_range

 $self->source_range(value => '0.001');

Query/Set the output range.

=cut

with 'Lab::Moose::Instrument::SCPI::Source::Function';

cache source_range => ( getter => 'source_range_query' );

sub source_range_query {
    my ( $self, %args ) = validated_getter( \@_ );

    return $self->cached_source_range(
        $self->query( command => "SOUR:RANG?", %args ) );
}

sub source_range {
    my ( $self, $value, %args ) = validated_setter(
        \@_,
    );

    $self->write( command => "SOUR:RANG $value", %args );

    $self->cached_source_range($value);
}

1;
