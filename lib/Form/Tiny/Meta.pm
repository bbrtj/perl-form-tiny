package Form::Tiny::Meta;

use v5.10;
use warnings;
use Moo;
use Types::Standard qw(ArrayRef HashRef InstanceOf CodeRef Bool);
use Scalar::Util qw(blessed);
use Carp qw(croak);

use Form::Tiny::FieldDefinition;
use Form::Tiny::FieldDefinitionBuilder;
use Form::Tiny::Hook;

use namespace::clean;

our $VERSION = '1.13';

has 'fields' => (
	is => 'ro',
	isa => ArrayRef [
		InstanceOf ['Form::Tiny::FieldDefinitionBuilder'] | InstanceOf ['Form::Tiny::FieldDefinition']
	],
	default => sub { [] },
);

has 'hooks' => (
	is => 'ro',
	isa => HashRef [
		ArrayRef [InstanceOf['Form::Tiny::Hook']]
	],
	default => sub { {} },
);

has 'complete' => (
	is => 'ro',
	isa => Bool,
	writer => '_complete',
	default => sub { 0 },
);

sub run_hooks_for
{
	my ($self, $stage, @data) = @_;

	my @hooks = @{$self->hooks->{$stage} // []};

	# running hooks always returns the last element they're passed
	for my $hook (@hooks) {
		my $ret = $hook->code->(@data);
		splice @data, -1, 1, $ret
			if $hook->is_modifying;
	}

	return pop @data;
}

sub setup
{
	my ($self) = @_;

	# at this point, all roles should already be merged and all inheritance done
	# we can make the meta definition complete
	$self->_complete(1);
	return;
}

sub resolved_fields
{
	my ($self, $object) = @_;

	croak 'resolved_fields requires form object'
		unless defined blessed $object;

	return [map {
		$_->isa('Form::Tiny::FieldDefinitionBuilder')
			? $_->build($object)
			: $_
	} @{$self->fields}];
}

sub add_field
{
	my ($self, @parameters) = @_;
	my $fields = $self->fields;

	croak 'adding a form field requires at least one parameter'
		unless scalar @parameters;

	my $scalar_param = shift @parameters;
	if (@parameters > 0 || ref $scalar_param eq '') {
		$scalar_param = { 'name', $scalar_param, @parameters };
	}

	push @{$fields}, Form::Tiny::FieldDefinitionBuilder->new(data => $scalar_param)->build;
	return $self;
}

sub add_hook
{
	my ($self, $hook, $code) = @_;

	push @{$self->hooks->{$hook}}, Form::Tiny::Hook->new(
		hook => $hook,
		code => $code
	);
	return $self;
}

sub inherit_from
{
	my ($self, $parent) = @_;

	croak 'can only inherit from objects of Form::Tiny::Meta'
		unless defined blessed $parent && $parent->isa('Form::Tiny::Meta');

	$self->fields([@{$parent->fields}, @{$self->fields}]);
	$self->hooks([@{$parent->hooks}, @{$self->hooks}]);
	return $self;
}

1;
