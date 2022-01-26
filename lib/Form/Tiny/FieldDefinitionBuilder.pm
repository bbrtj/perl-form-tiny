package Form::Tiny::FieldDefinitionBuilder;

use v5.10;
use strict;
use warnings;
use Moo;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use Types::Standard qw(HashRef);

use Form::Tiny::FieldDefinition;

use namespace::clean;

our $VERSION = '2.05';

has 'data' => (
	is => 'ro',
	required => 1,
);

has 'addons' => (
	is => 'ro',
	isa => HashRef,
	default => sub { {} },
);

sub build
{
	my ($self, $context) = @_;

	my $data = $self->data;
	my $dynamic = ref $data eq 'CODE';
	if ($dynamic && defined blessed $context) {
		croak 'building a dynamic field definition requires Form::Tiny::Form object'
			unless $context->DOES('Form::Tiny::Form');
		$data = $data->($context);
		$dynamic = 0;
	}

	return $self if $dynamic;

	my $definition;
	if (defined blessed $data && $data->isa('Form::Tiny::FieldDefinition')) {
		$definition = $data;
	}
	elsif (ref $data eq 'HASH') {
		$definition = Form::Tiny::FieldDefinition->new($data);
	}
	else {
		croak sprintf q{Invalid form field '%s' data: must be hashref or instance of Form::Tiny::FieldDefinition},
			$self->name;
	}

	$definition->addons($self->addons);

	return $definition;
}

1;
