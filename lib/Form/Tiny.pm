package Form::Tiny;

use Modern::Perl "2010";
use Moo::Role;
use Types::Standard qw(Str Maybe ArrayRef InstanceOf HashRef Bool);
use Carp qw(croak);

use Form::Tiny::FieldDefinition;
use Form::Tiny::Error;

our $VERSION = '1.00';

requires qw(build_fields);

has "field_defs" => (
	is => "rw",
	isa => ArrayRef[
		(InstanceOf["Form::Tiny::FieldDefinition"])
			->plus_coercions(HashRef, q{ Form::Tiny::FieldDefinition->new($_) })
	],
	coerce => 1,
	default => sub {
		[ shift->build_fields ]
	},
	trigger => \&_clear_form,
);

has "input" => (
	is => "rw",
	isa => HashRef,
	writer => "set_input",
	trigger => \&_clear_form,
);

has "fields" => (
	is => "rw",
	isa => Maybe[HashRef],
	writer => "_set_fields",
	clearer => "_clear_fields",
	predicate => 1,
);

has "valid" => (
	is => "ro",
	isa => Bool,
	writer => "_set_valid",
	lazy => 1,
	builder => "_validate",
	clearer => 1,
	predicate => "is_validated",
);

has "errors" => (
	is => "rw",
	isa => ArrayRef[InstanceOf["Form::Tiny::Error"]],
	writer => "_set_errors",
	lazy => 1,
	default => sub { [] },
	clearer => "_clear_errors",
	predicate => 1,
);

around "BUILDARGS" => sub {
	my ($orig, $class, @args) = @_;

	croak "Argument to Form::Tiny->new must be a single hashref"
		unless @args == 1 && ref $args[0] eq ref {};
	return {input => @args};
};

sub _clear_form {
	my ($self) = @_;

	$self->_clear_fields;
	$self->clear_valid;
	$self->_clear_errors;
}

sub add_error
{
	my ($self, $error) = @_;

	push @{$self->errors}, $error;
	return;
}

sub _validate
{
	my ($self) = @_;
	my $fields = $self->input;
	$self->_clear_errors;

	my $add_error = sub {
		my ($field, $error) = @_;
		$self->add_error(Form::Tiny::Error::DoesNotValidate->new(field => $field, error => $error));
	};

	my $found_args = 0;
	my $dirty = {};

	foreach my $validator (@{$self->field_defs}) {
		my $curr_f = $validator->name;

		if (exists $fields->{$curr_f}) {

			# argument exists, so count that
			$found_args += 1;

			# apply global filters, set up a scalarref to dirty arg
			$dirty->{$curr_f} = $fields->{$curr_f};
			my $current = \$dirty->{$curr_f};

			if ($self->does("Form::Tiny::Filtered")) {
				$$current = $self->_apply_filters($$current);
			}

			# if the parameter is required (hard), we only consider it if not empty
			if (!$validator->hard_required || ref $$current || length($$current // "")) {

				# coerce, validate, adjust
				$$current = $validator->get_coerced($$current);
				if ($validator->validate($add_error, $$current)) {
					$$current = $validator->get_adjusted($$current);
				}

				# found and valid, go to next field
				next;
			}
		}

		# for when it didn't pass the existence test
		if ($validator->required) {
			$self->add_error(Form::Tiny::Error::DoesNotExist->new(field => $curr_f));
		}
	}

	if ($self->does("Form::Tiny::Strict") && $self->strict && $found_args < keys %{$fields}) {
		$self->add_error(Form::Tiny::Error::IsntStrict->new);
	}

	$dirty = $self->clean($dirty)
		if $self->can("clean") && !$self->has_errors;

	my $form_valid = !$self->has_errors;
	$self->_set_fields($dirty)
		if $form_valid;

	return $form_valid;
}

no Moo::Role;
1;

__END__

=head1 NAME

Form::Tiny - Tiny form implementation centered around Type::Tiny

=head1 SYNOPSIS

  use Form::Tiny;

=head1 DESCRIPTION

