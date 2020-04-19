package Form::Tiny::FieldDefinition;

use Modern::Perl "2010";
use Moo;
use Types::Standard qw(Enum Bool HasMethods CodeRef Maybe Str);
use Types::Common::String qw(NonEmptySimpleStr);
use Carp qw(croak);

has "name" => (
	is => "ro",
	isa => NonEmptySimpleStr,
	required => 1,
);

has "required" => (
	is => "ro",
	isa => Enum[0, 1, "soft", "hard"],
	default => sub { 0 },
);

has "type" => (
	is => "ro",
	isa => Maybe[HasMethods["validate", "check"]],
);

has "coerce" => (
	is => "ro",
	isa => Bool | CodeRef,
	default => sub { 0 },
);

has "adjust" => (
	is => "ro",
	isa => CodeRef,
	predicate => "is_adjusted",
);

has "message" => (
	is => "ro",
	isa => Maybe[Str],
);

sub BUILD
{
	my ($self, $args) = @_;

	if ($self->coerce && ref $self->coerce ne "CODE") {
		# checks for coercion == 1
		my $t = $self->type;
		croak "the type doesn't provide coercion"
			if !defined $t || !($t->can("coerce") && $t->can("has_coercion") && $t->has_coercion);
	}
}

sub hard_required
{
	my ($self) = @_;

	return $self->required eq "hard" || $self->required eq "1";
}

sub get_coerced
{
	my ($self, $value) = @_;

	my $coerce = $self->coerce;
	if (ref $coerce eq "CODE") {
		return $coerce->($value);
	} elsif ($coerce) {
		return $self->type->coerce($value);
	} else {
		return $value;
	}
}

sub get_adjusted
{
	my ($self, $value) = @_;

	if ($self->is_adjusted) {
		return $self->adjust->($value);
	}
	return $value;
}

sub validate
{
	my ($self, $add_error, $value) = @_;

	# no validation if no type specified
	return 1
		if !defined $self->type;

	my $valid;
	my $error;
	if (defined $self->message) {
		$valid = $self->type->check($value);
		$error = $self->message;
	} else {
		$error = $self->type->validate($value);
		$valid = !defined $error;
	}

	if (!$valid) {
		$add_error->($self->name, $error);
	}

	return $valid;
}

no Moo;
1;
