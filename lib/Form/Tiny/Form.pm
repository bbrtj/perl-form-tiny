package Form::Tiny::Form;

use v5.10;
use warnings;
use Types::Standard qw(Maybe ArrayRef InstanceOf HashRef Bool);
use Carp qw(croak);
use Storable qw(dclone);
use Scalar::Util qw(blessed);

use Form::Tiny::PathValue;
use Form::Tiny::Error;
use Form::Tiny::Utils qw(get_package_form_meta);
use Moo::Role;

our $VERSION = '1.13';

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
	lazy => 1,
	builder => "_validate",
	clearer => 1,
	predicate => "is_validated",
	init_arg => undef,
);

has "errors" => (
	is => "ro",
	isa => ArrayRef [InstanceOf ["Form::Tiny::Error"]],
	lazy => 1,
	default => sub { [] },
	init_arg => undef,
);

sub _clear_form
{
	my ($self) = @_;

	$self->_clear_fields;
	$self->clear_valid;
	$self->_clear_errors;
}

sub _mangle_field
{
	my ($self, $def, $path_value) = @_;

	my $current = $path_value->value;

	# if the parameter is required (hard), we only consider it if not empty
	if (!$def->hard_required || ref $current || length($current // "")) {

		# coerce, validate, adjust
		$current = $def->get_coerced($self, $current);
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

	# the result goes here
	my @found;
	my $traverser;
	$traverser = sub {
		my ($curr_path, $path, $index, $value) = @_;
		my $last = $index == @{$path->meta};

		if ($last) {
			push @found, [$curr_path, $value];
		}
		else {
			my $next = $path->path->[$index];
			my $meta = $path->meta->[$index];

			if ($meta eq 'ARRAY' && ref $value eq 'ARRAY') {
				for my $ind (0 .. $#$value) {
					return    # may be an error, exit early
						unless $traverser->([@$curr_path, $ind], $path, $index + 1, $value->[$ind]);
				}

				if (@$value == 0) {
					# we wanted to have a deeper structure, but its not there, so clearly an error
					return unless $index == $#{$path->meta};

					# we had aref here, so we want it back in resulting hash
					push @found, [$curr_path, [], 1];
				}
			}
			elsif ($meta eq 'HASH' && ref $value eq 'HASH' && exists $value->{$next}) {
				return $traverser->([@$curr_path, $next], $path, $index + 1, $value->{$next});
			}
			else {
				# something's wrong with the input here - does not match the spec
				return;
			}
		}

		return 1;    # all ok
	};

	if ($traverser->([], $field_def->get_name_path, 0, $fields)) {
		return [map {
			Form::Tiny::PathValue->new(
				path => $_->[0],
				value => $_->[1],
				structure => $_->[2]
			)
		} @found];
	}
	return;
}

sub _assign_field
{
	my ($self, $fields, $field_def, $path_value) = @_;

	my @arrays = map { $_ eq 'ARRAY' } @{$field_def->get_name_path->meta};
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
	my $meta = $self->form_meta;
	$self->_clear_errors;

	if (ref $self->input eq 'HASH') {
		my $fields = $meta->run_hooks_for('before_validate', $self, dclone($self->input));
		foreach my $validator (@{$meta->resolved_fields($self)}) {
			my $curr_f = $validator->name;

			my $current_data = $self->_find_field($fields, $validator);
			if (defined $current_data) {
				my $all_ok = 1;

				# This may have multiple iterations only if there's an array
				foreach my $path_value (@$current_data) {
					unless ($path_value->structure) {
						my $value = $meta->run_hooks_for('before_mangle', $self, $validator, $path_value->value);
						$path_value->set_value($value);
						$all_ok = $self->_mangle_field($validator, $path_value) && $all_ok;
					}
					$self->_assign_field($dirty, $validator, $path_value);
				}

				# found and valid, go to the next field
				next if $all_ok;
			}

			# for when it didn't pass the existence test
			if ($validator->has_default) {
				$self->_assign_field($dirty, $validator, $validator->get_default($self));
			}
			elsif ($validator->required) {
				$self->add_error(Form::Tiny::Error::DoesNotExist->new(field => $curr_f));
			}
		}
	}
	else {
		$self->add_error(Form::Tiny::Error::InvalidFormat->new);
	}

	$meta->run_hooks_for('cleanup', $self, $dirty)
		if !$self->has_errors;

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
	my ($self, @error) = @_;

	my $error;
	if (@error == 1) {
		if (defined blessed $error[0]) {
			$error = shift @error;
			croak 'error passed to add_error must be an instance of Form::Tiny::Error'
				unless $error->isa("Form::Tiny::Error");
		}
		else {
			$error = Form::Tiny::Error->new(error => @error);
		}
	}
	elsif (@error == 2) {
		$error = Form::Tiny::Error->new(
			field => $error[0],
			error => $error[1],
		);
	}
	else {
		croak 'invalid arguments passed to $form->add_error';
	}

	push @{$self->errors}, $error;
	return $self;
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

sub form_meta
{
	my ($self) = @_;
	my $package = defined blessed $self ? blessed $self : $self;

	return get_package_form_meta($package);
}

1;
