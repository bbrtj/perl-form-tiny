package Form::Tiny::Strict;

use v5.10;
use warnings;
use Types::Standard qw(Bool);

use Form::Tiny::Utils;
use Form::Tiny::Error;
use Form::Tiny::FieldDefinition;

use Moo::Role;

our $VERSION = '1.13';

use constant {
	META_NOMETA => "",
	META_SKIP => "skip",
	META_ARRAY => "array",
	META_LEAF => "leaf",
};

requires qw(pre_validate _clear_form field_defs add_error);

has "strict" => (
	is => "ro",
	isa => Bool,
	builder => "build_strict",
	trigger => sub { shift->_clear_form },
	writer => "set_strict",
);

sub build_strict { 1 }

sub _check_recursive
{
	my ($self, $data, $meta, $path) = @_;
	$path //= Form::Tiny::Path->empty;

	my $current_path = $path->join;
	my $metadata = $meta->{$current_path} // META_NOMETA;

	return if $metadata eq META_SKIP;

	if ($metadata eq META_LEAF) {

		# we're at leaf and no error occured - we're good.
	}

	elsif ($metadata eq META_ARRAY) {
		die $current_path unless ref $data eq 'ARRAY';
		foreach my $value (@$data) {
			$self->_check_recursive(
				$value, $meta,
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
				$data->{$key}, $meta,
				$path->clone->append(HASH => $key)
			);
		}
	}
}

sub _check_strict
{
	my ($self, $input) = @_;

	my %meta;
	foreach my $def (@{$self->field_defs}) {
		if ($def->is_subform) {
			$meta{$def->name} = META_SKIP;
		}
		else {
			$meta{$def->name} = META_LEAF;
		}

		my $path = $def->get_name_path;
		my @path_meta = @{$path->meta};
		for my $ind (0 .. $#path_meta) {
			if ($path_meta[$ind] eq 'ARRAY') {
				$meta{$path->join($ind - 1)} = META_ARRAY;
			}
		}
	}

	my $error = try sub {
		$self->_check_recursive($input, \%meta);
	};

	if ($error) {
		$self->add_error(Form::Tiny::Error::IsntStrict->new);
	}
}

around "pre_validate" => sub {
	my ($orig, $self, $input) = @_;

	if ($self->strict) {
		$self->_check_strict($input);
	}
	$input = $self->$orig($input);

	return $input;
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

