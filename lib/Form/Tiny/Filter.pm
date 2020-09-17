package Form::Tiny::Filter;

use v5.10; use warnings;
use Moo;
use Types::Standard qw(HasMethods CodeRef);
use Carp qw(croak);

use namespace::clean;

has "type" => (
	is => "ro",
	isa => HasMethods["check"],
	required => 1,
);

has "code" => (
	is => "ro",
	isa => CodeRef,
	required => 1,
	writer => "set_code",
);


around "BUILDARGS" => sub {
	my ($orig, $class, @args) = @_;

	croak "Argument to Form::Tiny->new must be a single arrayref with two elements"
		unless @args == 1 && ref $args[0] eq ref [] && @{$args[0]} == 2;
	return {type => $args[0][0], code => $args[0][1]};
};

sub filter
{
	my ($self, $value) = @_;

	if ($self->type->check($value)) {
		return $self->code->($value);
	}

	return $value;
}

1;
