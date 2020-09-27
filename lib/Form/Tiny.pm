package Form::Tiny;

use v5.10; use warnings;
use Types::Standard qw(Str Maybe ArrayRef InstanceOf HashRef Bool CodeRef);
use Carp qw(croak);
use Storable qw(dclone);
use Scalar::Util qw(blessed);

use Form::Tiny::FieldDefinition;
use Form::Tiny::Error;
use Form::Tiny::FieldData;
use Moo::Role;

our $VERSION = '1.00';

with "Form::Tiny::Form";

requires qw(build_fields);

has "field_defs" => (
	is => "ro",
	isa => ArrayRef [
		(InstanceOf ["Form::Tiny::FieldDefinition"])
		->plus_coercions(HashRef, q{ Form::Tiny::FieldDefinition->new($_) })
	],
	coerce => 1,
	default => sub {
		[shift->build_fields]
	},
	trigger => \&_clear_form,
	writer => "set_field_defs",
);

has "input" => (
	is => "ro",
	writer => "set_input",
	trigger => \&_clear_form,
);

has "fields" => (
	is => "ro",
	isa => Maybe [HashRef],
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
	isa => ArrayRef [InstanceOf ["Form::Tiny::Error"]],
	default => sub { [] },
	init_arg => undef,
);

has "cleaner" => (
	is => "ro",
	isa => Maybe [CodeRef],
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

sub _clear_form
{
	my ($self) = @_;

	$self->_clear_fields;
	$self->clear_valid;
	$self->_clear_errors;
}

sub pre_mangle { $_[2] }
sub pre_validate { $_[1] }

sub _mangle_field
{
	my ($self, $def, $path_value) = @_;

	my $current = $path_value->value;

	# if the parameter is required (hard), we only consider it if not empty
	if (!$def->hard_required || ref $current || length($current // "")) {

		# coerce, validate, adjust
		$current = $def->get_coerced($current);
		if ($def->validate($self, $current)) {
			$current = $def->get_adjusted($current);
		}

		$path_value->set_value($current);
		return 1;
	}

	return;
}

sub _find_field
{
	my ($self, $fields, $field_def) = @_;

	my @found;
	my $traverser; $traverser = sub {
		my ($curr_path, $next_path, $value) = @_;

		if (@$next_path == 0) {
			push @found, [$curr_path, $value];
		}
		else {
			my $next = shift @$next_path;
			my $want_array = $next eq $Form::Tiny::FieldDefinition::array_marker;

			if ($want_array && ref $value eq ref []) {
				for my $index (0 .. $#$value) {
					return    # may be an error, exit early
						unless $traverser->([@$curr_path, $index], [@$next_path], $value->[$index]);
				}

				if (@$value == 0) {
					if (@$next_path > 0) {
						return;
					}
					else {
						# we had aref here, so we want it back in resulting hash
						push @found, [$curr_path, [], 1];
					}
				}
			}
			elsif (!$want_array && ref $value eq ref {} && exists $value->{$next}) {
				push @$curr_path, $next;
				return $traverser->($curr_path, $next_path, $value->{$next});
			}
			else {
				return;
			}
		}

		return 1;    # all ok
	};

	my @parts = $field_def->get_name_path;
	if ($traverser->([], \@parts, $fields)) {
		return Form::Tiny::FieldData->new(items => \@found);
	}
	return;
}

sub _assign_field
{
	my ($self, $fields, $field_def, $path_value) = @_;

	my @arrays = map { $_ eq $Form::Tiny::FieldDefinition::array_marker } $field_def->get_name_path;
	my @parts = @{$path_value->path};
	my $current = \$fields;
	for my $i (0 .. $#parts) {

		# array_path will contain array indexes for each array marker
		if ($arrays[$i]) {
			$current = \${$current}->[$parts[$i]];
		}
		else {
			$current = \${$current}->{$parts[$i]};
		}
	}

	$$current = $path_value->value;
}

sub _validate
{
	my ($self) = @_;
	my $dirty = {};
	$self->_clear_errors;

	if (ref $self->input eq ref {}) {
		my $fields = $self->pre_validate(dclone($self->input));
		foreach my $validator (@{$self->field_defs}) {
			my $curr_f = $validator->name;

			my $current_data = $self->_find_field($fields, $validator);
			if (defined $current_data) {
				my $all_ok = 1;

				# This may have multiple iterations only if there's an array
				foreach my $path_value (@{$current_data->items}) {
					unless ($path_value->structure) {
						$path_value->set_value($self->pre_mangle($validator, $path_value->value));
						$all_ok = $self->_mangle_field($validator, $path_value) && $all_ok;
					}
					$self->_assign_field($dirty, $validator, $path_value);
				}

				# found and valid, go to the next field
				next if $all_ok;
			}

			# for when it didn't pass the existence test
			if ($validator->required) {
				$self->add_error(Form::Tiny::Error::DoesNotExist->new(field => $curr_f));
			}
		}
	}
	else {
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

sub add_error
{
	my ($self, $error) = @_;
	croak "error has to be an instance of Form::Tiny::Error"
		unless blessed $error && $error->isa("Form::Tiny::Error");

	push @{$self->errors}, $error;
	return;
}

sub has_errors
{
	my ($self) = @_;
	return @{$self->errors} > 0;
}

sub _clear_errors
{
	my ($self) = @_;
	@{$self->errors} = ();
	return;
}

1;

__END__

=head1 NAME

Form::Tiny - Input validator implementation centered around Type::Tiny

=head1 SYNOPSIS

	use Moo;
	use Types::Common::String qw(SimpleStr);
	use Types::Common::Numeric qw(PositiveInt);

	with "Form::Tiny";

	sub build_fields {
		return (
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
		);
	}

	sub build_cleaner {
		my ($self, $data) = @_;

		if ($data->{name} eq "Perl" && $data->{lucky_number} == 6) {
			$self->add_error(Form::Tiny::Error::DoesNotValidate->new("Perl6 is Raku"));
		}
	}

=head1 DESCRIPTION

Form validation engine that can use all the type constraints you're already familiar with. The module does not ship with any field definitions on its own, instead it provides tools to reuse any type constraints from L<Type::Tiny> and other similar systems.

=head2 Policy

Form::Tiny is designed to be a comprehensive data validation and filtering system based on existing validation solutions. Type::Tiny libraries cover most of the validation and coercion needs in models, and now with Form::Tiny they can be empowered to do the same with input data.

The module itself isn't much more than a hashref filter - it accepts one as input and returns the transformed one as output. The pipeline is as follows:

	input
	  |
	  |--> filtering -- coercion -- validation -- adjustment -- cleaning --|
	                                                                       v
	                                                                     output

I<(Note that not every step on that pipeline is ran every time - it depends on form configuration)>

The module always tries to get as much data from input as possible and copy that into output. It will never copy any data that is not explicitly specified in the form fields configuration.

=head2 Basic usage

To use Form::Tiny as data validator you have to declare your own class mixing in the I<Form::Tiny> role and define a I<build_fields> sub, returning a list of field definitions for the form. A class containing these two basic requirements is ready to be instantiated and passed input to be validated.

Input can be passed as a hashref to the constructor or with the I<set_input> method. Every call to that method will cause the form instance to be cleared, so that it can be used again for different data.

	use MyForm;

	# either ...
	my $form = MyForm->new(\%data);

	# or ...
	my $form = MyForm->new;
	$form->set_input(\%data);

With input in place, a I<valid> method can be called, which will return a validation result and fill in the I<errors> and I<fields> properties. These properties are mutually exclusive: errors are only present if the validation is unsuccessful, otherwise the fields are present.

The example below illustrates how a form class could be used to validate data.

	use MyForm;

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

	sub build_fields {
		return (
			{ name => "some_name" },
			{ ... },
		);
	}

The only required element of this hashref is key I<name>, which contains the string with name of the field in the form input. Other possible elements are:

=over

=item type

The type that the field will be validated against. Effectively, this needs to be an object with I<validate> and I<check> methods implemented. All types from Type::Tiny meet this criteria.

=item coerce

A coercion that will be made B<before> the type is validated and will change the value of the field. This can be a coderef or a boolean:

Value of I<1> means that coercion will be applied from the specified I<type>. This requires the type to also provide I<coerce> and I<has_coercion> method, and the return value of the second one must be true.

Value of I<0> means no coercion will be made. This is the default behavior.

Value that is a coderef will be passed a single scalar, which is the value of the field. It is required to make its own checks and return a scalar which will replace the old value.

=item adjust

An adjustment that will be made B<after> the type is validated and the validation is successful. This must be a coderef that gets passed the validated value and returns the new value for the field (just like the coderef version of coercion).

At the point of adjustment, you can be sure that the value passed to the coderef meets the type constraint specified. It's probably a good idea to provide a type along with the adjustment to avoid unnecessary checks in the subroutine - if no type is specified, then any value from the input data will end up in the coderef.

=item required

Controls if the field should be skipped silently if it has no value or the value is empty. Possible values are:

I<0> - The field can be non-existent in the input, empty or undefined. This is the default behavior

I<"soft"> - The field has to exist in the input, but can be empty or undefined

I<1> or I<"hard"> - The field has to exist in the input, must be defined and non-empty (a value I<0> is allowed, but an empty string is disallowed)

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

Attaching more behavior to the form is possible by overriding I<pre_mangle> and I<pre_validate> methods in the final class. These methods do nothing by default, but roles that are introducing extra behavior set up C<around> hooks for them. It's okay not to invoke the SUPER version of these methods if you're overriding them.

B<pre_mangle> is fired for every field, just before it is changed ("mangled"). In addition to an object reference, this method will be passed the definition of the field (L<Form::Tiny::FieldDefinition>) and a scalar value of the field. The field must exist in the input data for this method to fire, but can be undefined. The return value of this method will become the new value for the field.

	sub pre_mangle {
		my ($self, $field_definition, $value) = @_;

		// do something with $value

		return $value;
	}

B<pre_validate> is fired just once for the form, before any field is validated. It is passed a single hashref - a copy of the input data. This method is free to do anything with the input, and its return value will become the real input to the validation.

	sub pre_validate {
		my ($self, $input_data) = @_;

		// do something with $input_data

		return $input_data;
	}

The module provides two roles which use these mechanisms to achieve common tasks.

=over

=item L<Form::Tiny::Strict>

Enables strict mode for the form. Validation will fail if the form input contains any data not specified in the field definitions.

=item L<Form::Tiny::Filtered>

Enables initial filtering for the input fields. By default, this will only cause strings to be trimmed, but any code can be attached to any field that meets a given type constraint. See the role documentation for details

=back

=head2 Inline forms

The module also enables a way to create a form without the need of a dedicated package. This is done with the L<Form::Tiny::Inline> class. This requires the user to pass all the data to the constructor, as shown in the example:

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

=head3 Nested arrays

Nesting adds many new options, but it can only handle hashes. Regular arrays can of course be handled by I<ArrayRef> type from Type::Tiny, but that's a hassle. Instead, you can use a star (I<*>) as the only element inside the nesting segment to expect an array there. Adding named fields can be resumed after that, but needn't.

For example, C<< name => "arr.*.some_key" >> expects I<arr> to be an array reference, with each element being a hash reference containing a key I<some_key>. Note that any array element that fails to contain wanted hash elements will cause the field to be ignored in the output (since input does not meet the specification entirely). If you want the validation to fail instead, you need to make the nested element required.

	# This input data ...
	{
		arr => [
			{ some_key => 1 },
			{ some_other_key => 2 },
			{ some_key => 3 },
		]
	}

	# Would become ...
	{
		arr => [
			{ some_key => 1 },
			undef,
			{ some_key => 3 },
		]
	}

	# Make the element required to make the validation fail instead

Other example is two nested arrays that not necessarily contain a hash at the end: C<< name => "arr.*.*" >>. The leaf values here can be simple scalars. Empty array elements will be turned to C<undef>, same as in the example above.

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

Be aware of a special case, an adjustment will be inserted here automatically like the following:

	adjust => sub { $instance->fields }

this will make sure that any coercions and adjustments made in the nested form will be added to the outer form as well. If you want to specify your own adjustment here, make sure to use the data provided by the I<fields> method of the nested form.

TODO extra data to fields
