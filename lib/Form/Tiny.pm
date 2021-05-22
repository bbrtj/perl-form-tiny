package Form::Tiny;

use v5.10;
use warnings;
use Carp qw(croak);
use Import::Into;

use Form::Tiny::Form;
require Moo;

our $VERSION = '1.13';

sub import
{
	my ($package, $caller) = (shift, scalar caller);

	my @wanted = @_;
	my @wanted_subs = qw(form_field form_cleaner form_hook);
	my @wanted_roles;

	my %subs = %{$package->_generate_helpers($caller)};
	my %behaviors = %{$package->_get_behaviors};

	# TODO make Moo optional?
	Moo->import::into($caller);

	require Moo::Role;
	Moo::Role->apply_roles_to_package(
		$caller, 'Form::Tiny::Form'
	);

	foreach my $type (@wanted) {
		croak "no Form::Tiny import behavior for: $type"
			unless exists $behaviors{$type};
		push @wanted_subs, @{$behaviors{$type}->{subs}};
		push @wanted_roles, @{$behaviors{$type}->{roles}};
	}

	Form::Tiny::Form->_create_meta($caller, @wanted_roles);

	{
		no strict 'refs';
		no warnings 'redefine';

		*{"${caller}::$_"} = $subs{$_} foreach @wanted_subs;
	}

	return;
}

sub _generate_helpers
{
	my ($package, $caller) = @_;

	return {
		form_field => sub {
			$caller->form_meta->add_field(@_);
		},
		form_cleaner => sub {
			$caller->form_meta->add_hook(cleanup => @_);
		},
		form_hook => sub {
			$caller->form_meta->add_hook(@_);
		},
		form_filter => sub {
			$caller->form_meta->add_filter(@_);
		},
	};
}

sub _get_behaviors
{
	return {
		# for backcompat
		-base => {
			subs => [],
			roles => [],
		},
		-strict => {
			subs => [],
			roles => [qw(Form::Tiny::Strict)],
		},
		-filtered => {
			subs => [qw(form_filter)],
			roles => [qw(Form::Tiny::Filtered)],
		},
	};
}

1;

__END__

=head1 NAME

Form::Tiny - Input validator implementation centered around Type::Tiny

=head1 SYNOPSIS

	package MyForm;

	use Form::Tiny -base;

	form_filed 'my_field' => (
		required => 1,
	);

	form_filed 'another_field' => (
		required => 1,
	);

=head1 DESCRIPTION

Main package of the Form::Tiny system - this is a role that provides most of the module's functionality.

=head1 DOCUMENTATION INDEX

=over

=item * L<Form::Tiny::Manual> - main reference

=item * L<Form::Tiny::Manual::Internals> - Form::Tiny without syntactic sugar

=item * Most regular packages contains information on symbols they contain.

=back

=head1 IMPORTING

Starting with version 1.10 you can enable syntax helpers by using import flags:

	package MyForm;

	# imports form_field and form_cleaner helpers
	use Form::Tiny -base;

	# imports form_field, form_filter and form_cleaner helpers
	use Form::Tiny -filtered;

	# fully-featured form:
	use Form::Tiny -filtered, -strict;


=head2 IMPORTED FUNCTIONS

=head3 form_field

	form_field $name => %arguments;
	form_field $name => $coderef;

Imported when any flag is present. $coderef gets passed the form instance and should return a hashref. Neither %arguments nor $coderef return data should include the name in the hash, it will be copied from the first argument.

Note that this field definition method is not capable of returning a subclass of L<Form::Tiny::FieldDefinition>. If you need a subclass, you will need to use bare-bones method of form construction. Refer to L<Form::Tiny::Manual::Internals> for details.

=head3 form_cleaner

	form_cleaner $sub;

Imported when any flag is present. C<$sub> will be ran as the very last step of form validation. There can't be more than one cleaner in a form. See L</build_cleaner>.

=head3 form_filter

	form_filter $type, $sub;

Imported when the -filtered flag is present. $type should be a Type::Tiny (or compatible) type check. For each input field that passes that check, $sub will be ran. See L<Form::Tiny::Filtered> for details on filters.

=head1 ADDED INTERFACE

This section describes the interface added to your class after mixing in the Form::Tiny role.

=head2 ATTRIBUTES

Each of the attributes can be accessed by calling its name as a function on Form::Tiny object.

=head3 field_defs

Contains an array reference of L<Form::Tiny::FieldDefinition> instances. A coercion from a hash reference can be performed upon writing.

B<built by:> I<build_fields>

=head3 input

Contains the input data passed to the form.

B<writer:> I<set_input>

=head3 fields

Contains the validated and cleaned fields set after the validation is complete. Cannot be specified in the constructor.

=head3 valid

Contains the result of the validation - a boolean value. Gets produced lazily upon accessing it, so calling C<< $form->valid; >> validates the form automatically.

B<clearer:> I<clear_valid>

B<predicate:> I<is_validated>

=head3 errors

Contains an array reference of form errors which were detected by the last performed validation. Each error is an instance of L<Form::Tiny::Error>.

B<predicate:> I<has_errors>

=head2 METHODS

This section describes standalone methods available in the module - they are not directly connected to any of the attributes.

=head3 new

This is a Moose-flavored constructor for the class. It accepts a hash or hash reference of parameters, which are the attributes specified above.

=head3 check

=head3 validate

These methods are here to ensure that a Form::Tiny instance can be used as a type validator itself by other form classes.

I<check> returns a boolean value that indicates whether the validation of input data was successful.

I<validate> does the same thing, but instead of returning a boolean it returns a list of errors that were detected, or undef if none.

Both methods take input data as the only argument.

=head3 add_error

Adds an error to form - should be called with an instance of L<Form::Tiny::Error> as its only argument. This should only be done during validation with customization methods listed below.

=head1 CUSTOMIZATION

A form instance can be customized by overriding any of the following methods:

=head2 build_fields

This method should return an array or array reference of field definitions: either L<Form::Tiny::FieldDefinition> instances or hashrefs which can be used to construct these instances.

It is passed a single argument, which is the class instance. It can be used to add errors in coderefs or to use class fields in form building.

=head2 build_cleaner

An optional cleaner is a function that will be called as the very last step of the validation process. It can be used to have a broad look on all of the validated form fields at once and introduce any synchronization errors, like a field requiring other field to be set.

Using I<add_error> inside this function will cause the form to fail the validation process.

In I<build_cleaner> method you're required to return a subroutine reference that will be called with two arguments: a form being validated and a set of "dirty" fields - validated and ready to be cleaned. This subroutine should not return the data - its return value will be discarded.

=head2 pre_mangle

This method is called every time an input field value is about to be changed by coercing and adjusting. It gets passed two arguments: an instance of L<Form::Tiny::FieldDefinition> and a value obtained from input data.

This method should return a new value for the field, which will replace the old one.

=head2 pre_validate

This method is called once before the validation process has started. It gets passed a deep copy of input data and is expected to return a value that will be used to obtain every field value during validation.

=head1 AUTHOR

Bartosz Jarzyna E<lt>brtastic.dev@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 - 2021 by Bartosz Jarzyna

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
