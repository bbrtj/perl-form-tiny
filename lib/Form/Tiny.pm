package Form::Tiny;

use Modern::Perl "2010";
use Types::Standard qw(Str Maybe ArrayRef InstanceOf HashRef Bool CodeRef);
use Carp qw(croak);
use Storable qw(dclone);

use Form::Tiny::FieldDefinition;
use Form::Tiny::Error;
use Moo::Role;
use Sub::HandlesVia;

our $VERSION = '1.00';

with "Form::Tiny::Form";

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
	writer => "set_input",
	trigger => \&_clear_form,
);

has "fields" => (
	is => "rw",
	isa => Maybe[HashRef],
	writer => "_set_fields",
	clearer => "_clear_fields",
	init_arg => undef,
);

has "valid" => (
	is => "ro",
	isa => Bool,
	writer => "_set_valid",
	lazy => 1,
	builder => "_validate",
	clearer => 1,
	predicate => "is_validated",
	init_arg => undef,
);

has "errors" => (
	is => "ro",
	isa => ArrayRef[InstanceOf["Form::Tiny::Error"]],
	default => sub { [] },
	init_arg => undef,
	handles_via => "Array",
	handles => {
		"add_error" => "push",
		"has_errors" => "count",
		"_clear_errors" => "clear",
	},
);

has "cleaner" => (
	is => "rw",
	isa => Maybe[CodeRef],
	default => sub {
		shift->can("build_cleaner");
	},
);

around BUILDARGS => sub {
	my ($orig, $class, @args) = @_;

	return {input => @args}
		if @args == 1;

	return {@args};
};

sub _clear_form {
	my ($self) = @_;

	$self->_clear_fields;
	$self->clear_valid;
	$self->_clear_errors;
}

sub _pre_mangle {}
sub _pre_validate {}

sub _mangle_field
{
	my ($self, $def, $current) = @_;

	# if the parameter is required (hard), we only consider it if not empty
	if (!$def->hard_required || ref $$current || length($$current // "")) {

		# coerce, validate, adjust
		$$current = $def->get_coerced($$current);
		if ($def->validate($self, $$current)) {
			$$current = $def->get_adjusted($$current);
		}
		return 1;
	}
	return 0;
}

sub _find_field
{
	my ($self, $fields, $field_def) = @_;

	my @parts = $field_def->get_name_path;
	my $current = $fields;
	for my $i (0 .. $#parts) {
		last unless ref $current eq ref {} && exists $current->{$parts[$i]};

		if ($i == $#parts) {
			return \$current->{$parts[$i]};
		} else {
			$current = $current->{$parts[$i]};
		}
	}

	return;
}

sub _assign_field
{
	my ($self, $fields, $field_def, $val_ref) = @_;

	my @parts = $field_def->get_name_path;
	my $current = $fields;
	for my $i (0 .. $#parts) {
		if ($i == $#parts) {
			$current->{$parts[$i]} = $$val_ref;
			return \$current->{$parts[$i]};
		} else {
			$current->{$parts[$i]} //= {};
			$current = $current->{$parts[$i]};
		}
	}
}

sub _validate
{
	my ($self) = @_;
	my $dirty = {};
	$self->_clear_errors;

	if (ref $self->input eq ref {}) {
		my $fields = dclone($self->input);
		$self->_pre_validate($fields);
		foreach my $validator (@{$self->field_defs}) {
			my $curr_f = $validator->name;

			my $current = $self->_find_field($fields, $validator);
			if (defined $current) {

				$current = $self->_assign_field($dirty, $validator, $current);
				$self->_pre_mangle($validator, $current);

				# found and valid, go to the next field
				next if $self->_mangle_field($validator, $current);
			}

			# for when it didn't pass the existence test
			if ($validator->required) {
				$self->add_error(Form::Tiny::Error::DoesNotExist->new(field => $curr_f));
			}
		}
	} else {
		$self->add_error(Form::Tiny::Error::InvalidFormat->new);
	}

	$self->cleaner->($self, $dirty)
		if defined $self->cleaner && !$self->has_errors;

	my $form_valid = !$self->has_errors;
	$self->_set_fields($form_valid ? $dirty : undef);

	return $form_valid;
}

sub check
{
	my ($self, $input) = @_;

	$self->set_input($input);
	return $self->valid;
}

sub validate
{
	my ($self, $input) = @_;

	return if $self->check($input);
	return $self->errors;
}

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

	sub build_cleaner {
		my ($self, $data) = @_;

		if ($data->{name} eq "Perl" && $data->{lucky_number} == 6) {
			$self->add_error(Form::Tiny::Error::DoesNotValidate->new("Perl6 is Raku"));
		}
	}

=head1 DESCRIPTION

Form validation engine that can use all the type constraints you're already familiar with. The module does not ship with any field definitions on its own, instead it provides tools to reuse any type constraints from L<Type::Tiny> and other similar systems.

=head2 Basic usage

To use Form::Tiny as data validator you have to declare your own class mixing in the I<Form::Tiny> role and define a I<build_fields> sub, returning a list of field definitions for the form. A class containing these two basic requirements is ready to be instantiated and passed input to be validated.

Input can be passed as a hashref to the constructor or with the I<set_input> method. Every call to that method will cause the form instance to be cleared, so that it can be used again for different data.

With input in place, a I<valid> method can be called, which will return a validation result and fill in the I<errors> and I<fields> properties. These properties are mutually exclusive: errors are only present if the validation is unsuccessful, otherwise the fields are present.

The example below illustrates how a form class could be used to validate data.

	my $form = MyForm->new;
	$form->set_input($some_input);

	if ($form->valid) {
		my $fields = $form->fields; # a hash reference
		...
	} else {
		my $errors = $form->errors; # an array reference
		...
	}

=head2 Form building

Every class applying the I<Form::Tiny> role has to have a sub called I<build_fields>. This method should return a list of hashrefs, where each of them will be coerced into an object of the L<Form::Tiny::FieldDefinition> class. You can also provide an instance of the class yourself, which should be helpful if you're willing to use your own definition implementation.

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
At the point of adjustment, you can be sure that the value passed to the coderef meets the type constraint specified. It's probably a good idea to provide adjustment along with a type to avoid unnecessary checks in the subroutine.

=item required

Controls if the field should be skipped silently if it has no value or the value is empty. Possible values are:

I<0> - The field can be non-existent in the input, empty or undefined

I<"soft"> - The field has to exist in the input, but can be empty or undefined

I<1> or I<"hard"> - The field has to exist in the input, must be defined and non-empty (a value I<0> is allowed)

=item message

A static string that should be output instead of an error message returned by the I<type> when the validation fails.

=back

=head2 Cleaning

While I<build_fields> allows for single-field validation, sometimes a need arises to check if some fields are synchronized correctly. This can be done with the I<build_cleaner> method, which will be only fired after the validation for every individual field was successful. The cleaner subroutine should look like this:

	sub build_cleaner {
		my ($self, $data) = @_;

		# do something with $data
		# call $self->add_error if necessary
	}

Cleaning sub is also allowed to change the $data, which is a hash reference to the runnig copy of the input. Note that this is the final step in the validation process, so anything that is in $data after cleaning will be available in the form's I<fields> after validation.

=head2 Optional behavior

Attaching more behavior to the form is possible by overriding I<_pre_mangle> and I<_pre_validate> methods in the final class. These methods do nothing by default so it's fine to discard the SUPER version.

I<_pre_mangle> is fired for every field, just before it is changed ("mangled"). This method will be passed the definition of the field (L<Form::Tiny::FieldDefinition>) and a scalar reference to its value.

I<_pre_validate> is fired just once for the form, before any field is validated. It is passed a single hashref - a copy of the input data.

The module provides two roles which use these mechanisms to achieve common tasks.

=over

=item L<Form::Tiny::Strict>

Enables strict mode for the form. Validation will fail if the form input contains any data not specified in the field definitions.

=item L<Form::Tiny::Filtered>

Enables initial filtering for the input fields. By default, this will only cause strings to be trimmed, but any code can be attached to any field that meets a given type constraint.

=back

=head2 Inline forms

The module also enables a way to create a form without the need of a dedicated module. This is done with the L<Form::Tiny::Inline> class. This requires the user to pass all the data to the constructor, as shown in the example:

	my $form = Form::Tiny::Inline # An inline form ...
		        ->is(qw/Strict/)   # ... with the strict role mixed in ...
		        ->new(             # ... will be created with properties:
		field_defs => [{name => "my_field"}],
		cleaner => sub { ... },
	);

The names changes a little - the regular I<build_fields> builder method becomes a I<field_defs> property, I<build_cleaner> becomes just a I<cleaner> property. This is because these methods implemented in classes are only builders for the underlying Moo properties, and with inline class these properties have to be assigned directly, not built.

=head2 Advanced topics

=head3 Nested fields

A dot (I<.>) can be used in the name of a field to express hashref nesting. A field with C<< name => "a.b.c" >> will be expected to be found under the key "c", in the hashref under the key "b", in the hashref under the key "a", in the root input hashref.

This is the default behavior of a dot in a field name, so if what you want is the actual dot it has to be preceded with a backslash (I<\.>).

=head3 Nested forms

Every form class created with the I<Form::Tiny> role mixed in can be used as a field definition type in other form. The outer and inner forms will validate independently, but inner form errors will be added to outer form with the outer field name prepended.

	# in Form2
	sub build_fields {
		# everything under "nested" key will be validated using Form1 instance
		# every error for "nested" will also start with "nested"
		return ({
			name => "nested",
			type => Form1->new,
		});
	}

Note that an adjustment will be inserted here automatically, in form of:

	adjust => sub { $instance->fields }

this will make sure that any coercions and adjustments made in the nested form will be added to the outer form as well. If you want to specify your own adjustment here, make sure to use the data provided by the I<fields> method of the nested form.

TODO extra data to fields
