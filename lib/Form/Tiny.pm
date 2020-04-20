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

	use Moo;
	use Types::Common::String qw(SimpleStr);
	use Types::Common::Numeric qw(PositiveInt);

	with "Form::Tiny";

	sub build_fields {
		{
			name => "name",
			type => SimpleStr,
			adjust => sub { ucfirst shift },
			required => 1,
		},
		{
			name => "lucky_number",
			type => PositiveInt,
			required => 1,
		}
	}

	sub clean {
		my ($self, $data) = @_;

		if ($data->{name} eq "Perl" && $data->{lucky_number} == 6) {
			$self->add_error(Form::Tiny::Error::DoesNotValidate->new("Perl6 is Raku"));
		}

		return $data;
	}

=head1 DESCRIPTION

Form validation engine that can reuse all the type constraints you're already familiar with.

=head1 FORM BUILDING

Every class applying the I<Form::Tiny> role has to have a sub called I<build_fields>. This method should return a list of hashrefs, where each of them will be coerced into an object of the L<Form::Tiny::FieldDefinition> class.

The only required element of this hashref is I<name>, which contains the string name of the field in the form input. Other possible elements are:

=over

=item type

A type that the field will be validated against. Effectively, this needs to be an object with I<validate> and I<check> methods.

=item coerce

A coercion that will be made B<before> the type is validated and will change the value of the field. This can be a coderef or a boolean:

Value of I<1> means that coercion will be applied from the specified I<type>. This requires the type to also provide I<coerce> and I<has_coercion> method, and the return value of the second one must be true.

Value of I<0> means no coercion will be made.

Value that is a coderef will be passed a single scalar, which is the value of the field. It is required to make its own checks and return a scalar which will replace the old value.

=item adjust

An adjustment that will be made B<after> the type is validated and the validation is successful. This must be a coderef that gets passed the validated value and returns the new value for the field.

=item required

Controls if the field should be skipped silently if it has no value or the value is empty. Possible values are:

I<0> - The field can be non-existent in the input, empty or undefined

I<"soft"> - The field has to exist in the input, but can be empty or undefined

I<1> or I<"hard"> - The field has to exist in the input, must be defined and non-empty (value of I<0> is allowed)

=item message

A static string that should be output instead of an error message returned by the I<type> when the validation fail.

=back
