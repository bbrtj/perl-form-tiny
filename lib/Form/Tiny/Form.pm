package Form::Tiny::Form;

use v5.10;
use warnings;
use Types::Standard qw(Maybe ArrayRef InstanceOf HashRef Bool);
use Carp qw(croak);
use Storable qw(dclone);
use Scalar::Util qw(blessed);

use Form::Tiny::Meta;
use Form::Tiny::PathValue;
use Form::Tiny::Error;
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
	my ($self, $error) = @_;
	# TODO easier default error adding
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

# FORM METADATA
our $meta_class = 'Form::Tiny::Meta';
my %meta;

sub _create_anon_meta
{
	my ($self, @roles) = @_;
	my $meta = $meta_class->new;

	require Moo::Role;
	Moo::Role->apply_roles_to_object(
		$meta, @roles
	) if scalar @roles;

	return $meta;
}

sub _create_meta
{
	my ($self, $package, @roles) = @_;

	croak "form meta for $package already exists"
		if exists $meta{$package};

	$meta{$package} = $self->_create_anon_meta(@roles);

	return $meta{$package};
}

sub form_meta
{
	my ($self) = @_;
	my $package = defined blessed $self ? blessed $self : $self;

	croak "no form meta declared for $package"
		unless exists $meta{$package};

	my $form_meta = $meta{$package};

	if (!$form_meta->complete) {
		# when this breaks, mst gets to point and laugh at me
		my @parents = do {
			no strict 'refs';
			@{"${package}::ISA"};
		};

		foreach my $parent (@parents) {
			$form_meta->inherit_from($parent->form_meta)
				if $parent->DOES('Form::Tiny::Form');
		}
		$form_meta->setup;
	}

	return $form_meta;
}

1;
