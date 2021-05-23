package Form::Tiny::Meta::Strict;

use v5.10;
use warnings;

use Form::Tiny::Utils qw(try);
use Form::Tiny::Error;

use Moo::Role;

our $VERSION = '2.00';

use constant {
	MARKER_NONE => "",
	MARKER_SKIP => "skip",
	MARKER_ARRAY => "array",
	MARKER_LEAF => "leaf",
};

requires qw(setup);

sub _check_recursive
{
	my ($self, $obj, $data, $markers, $path) = @_;
	$path //= Form::Tiny::Path->empty;

	my $current_path = $path->join;
	my $metadata = $markers->{$current_path} // MARKER_NONE;

	return if $metadata eq MARKER_SKIP;

	if ($metadata eq MARKER_LEAF) {

		# we're at leaf and no error occured - we're good.
	}

	elsif ($metadata eq MARKER_ARRAY) {
		die $current_path unless ref $data eq 'ARRAY';
		foreach my $value (@$data) {
			$self->_check_recursive(
				$obj, $value, $markers,
				$path->clone->append('ARRAY')
			);
		}
	}

	else {
		# only leaves are allowed to be anything
		# on regular elements we expect a hashref
		die $current_path unless ref $data eq 'HASH';
		for my $key (keys %$data) {
			$self->_check_recursive(
				$obj, $data->{$key}, $markers,
				$path->clone->append(HASH => $key)
			);
		}
	}
}

sub _check_strict
{
	my ($self, $obj, $input) = @_;

	my %markers;
	foreach my $def (@{$obj->field_defs}) {
		if ($def->is_subform) {
			$markers{$def->name} = MARKER_SKIP;
		}
		else {
			$markers{$def->name} = MARKER_LEAF;
		}

		my $path = $def->get_name_path;
		my @path_meta = @{$path->meta};
		for my $ind (0 .. $#path_meta) {
			if ($path_meta[$ind] eq 'ARRAY') {
				$markers{$path->join($ind - 1)} = MARKER_ARRAY;
			}
		}
	}

	my $error = try sub {
		$self->_check_recursive($obj, $input, \%markers);
	};

	if ($error) {
		$obj->add_error(Form::Tiny::Error::IsntStrict->new);
	}

	return $input;
}

after 'setup' => sub {
	my ($self) = @_;

	$self->add_hook(
		Form::Tiny::Hook->new(
			hook => 'before_validate',
			code => sub { $self->_check_strict(@_) },
			inherited => 0,
		)
	);
};

1;

__END__

=head1 NAME

Form::Tiny::Strict - mark input with extra data as invalid

=head1 SYNOPSIS

	# in your form class
	use Form::Tiny -strict;

	# optional - 1 by default, 0 turns strict checking off
	sub build_strict { 0 }

=head1 DESCRIPTION

This is a simple role that will cause any extra data on input to fail the form validation.

For example, if your form contains many optional fields which change often, you may want to ensure that your users are not sending anything you're not going to handle. This can help debugging and prevent errors.

=head1 ADDED INTERFACE

=head2 ATTRIBUTES

=head3 strict

Stores a single boolean, which determines if strict checking is turned on. Turning it off effectively disables the role.

B<writer:> I<set_strict>

=head2 METHODS

=head3 build_strict

This method should return the default value for the I<strict> attribute.

It is optional and returns I<1> by default.

