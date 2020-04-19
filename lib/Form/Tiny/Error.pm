package Form::Tiny::Error;

use Modern::Perl "2010";
use Moo;
use Types::Standard qw(Maybe Str Object);
use Carp qw(confess);

use overload
  q{""}    => "as_string",
  fallback => 1;

has "field" => (
	is => "rw",
	isa => Maybe[Str],
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

no Moo;
1;
