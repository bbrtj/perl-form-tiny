package Form::Tiny::Error;

use v5.10; use warnings;
use Moo;
use Types::Standard qw(Maybe Str Object ArrayRef InstanceOf);
use Carp qw(confess);

use namespace::clean;

use overload
	q{""} => "as_string",
	fallback => 1;

has "field" => (
	is => "ro",
	isa => Maybe [Str],
	writer => "set_field",
);

has "error" => (
	is => "ro",
	isa => Str | Object,
	builder => "_default_error",
);

sub _default_error
{
	confess "no error message supplied";
	return "Unknown error";
}

sub as_string
{
	my ($self) = @_;

	my $field = $self->field // "general";
	my $error = $self->error;
	return "$field - $error";
}

# in-place subclasses

{

	package Form::Tiny::Error::InvalidFormat;
	use parent "Form::Tiny::Error";

	sub _default_error
	{
		return "input data has invalid format";
	}
}

{

	package Form::Tiny::Error::DoesNotExist;
	use parent "Form::Tiny::Error";

	sub _default_error
	{
		return "does not exist";
	}
}

{

	package Form::Tiny::Error::IsntStrict;
	use parent "Form::Tiny::Error";

	sub _default_error
	{
		return "does not meet the strictness criteria";
	}
}

{

	package Form::Tiny::Error::DoesNotValidate;
	use parent "Form::Tiny::Error";

	sub _default_error
	{
		return "validation fails";
	}
}

1;
