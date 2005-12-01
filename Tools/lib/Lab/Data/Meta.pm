#!/usr/bin/perl -w

#$Id$

package Lab::Data::Meta;

use strict;
use Lab::Data::XMLtree;
require Exporter;

our @ISA = qw(Exporter Lab::Data::XMLtree);

our $VERSION = sprintf("1.%04d", q$Revision$ =~ / (\d+) /);

our $AUTOLOAD;

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

my $declaration = {
	filename_base			=> ['PSCALAR'],#	PSCALAR! Dient als basename f�r DATA und META
	filename_path			=> ['PSCALAR'],#	PSCALAR! Dient als speicherpfad f�r DATA und META

	dataset_title			=> ['SCALAR'],
	dataset_description		=> ['SCALAR'],
	data_file				=> ['SCALAR'],#		relativ zur descriptiondatei

	block					=> [
		'ARRAY',
		'id',
		{
			original_filename	=> ['SCALAR'],
			timestamp			=> ['SCALAR'],
			comment				=> ['SCALAR']
		}
	],
	column					=> [
		'ARRAY',
		'id',
		{
			unit		=> ['SCALAR'],
			label		=> ['SCALAR'],
			description	=> ['SCALAR'],
			min			=> ['PSCALAR'],
			max			=> ['PSCALAR']
		}
	],
	axis					=> [
		'HASH',
		'label',
		{
#			column		=> ['SCALAR'],	# entfernt, da schwachsinnig. soll per expression auch mehrere spalten abdecken k�nnen
			unit		=> ['SCALAR'],
			logscale	=> ['SCALAR'],
			expression	=> ['SCALAR'],
			min			=> ['SCALAR'],
			max			=> ['SCALAR'],
			description	=> ['SCALAR']
		}
	],
};

sub new {
	my $proto = shift;
    my $class = ref($proto) || $proto;
    bless $class->SUPER::new($declaration,@_), $class;
}

1;

__END__

=head1 NAME

Lab::Data::Meta - Meta data for datasets

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new([$config][,$basepathname])

=head1 METHODS

=head2 Description Methods done via AUTOLOAD

=head1 AUTHOR/COPYRIGHT

This is $Id$

Copyright 2004 Daniel Schr�er (L<http://www.danielschroeer.de>)

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
