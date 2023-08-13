package Form::Tiny::Plugin::Strict;

use v5.10;
use strict;
use warnings;

use Form::Tiny::Utils qw(try);
use Form::Tiny::Error;

use parent 'Form::Tiny::Plugin';

sub plugin
{
	my ($self, $caller, $context) = @_;

	return {
		meta_roles => [__PACKAGE__],
	};
}

use Moo::Role;

use constant {
	MARKER_NONE => 0,
	MARKER_ARRAY => 1,
	MARKER_LEAF => 2,
};

requires qw(setup);

sub _check_recursive
{
	my ($self, $data, $markers, $path) = @_;

	my $current_path = $path->join;
	my $metadata = $markers->{$current_path} // MARKER_NONE;

	if ($metadata == MARKER_LEAF) {

		# we're at leaf and no error occured - we're good.
	}

	elsif ($metadata == MARKER_ARRAY) {
		die $current_path unless ref $data eq 'ARRAY';

		# no need to clone el for each array element
		my $subel_path = $path->clone->append('ARRAY');
		foreach my $value (@$data) {
			$self->_check_recursive($value, $markers, $subel_path);
		}
	}

	else {
		# only leaves are allowed to be anything
		# on regular elements we expect a hashref
		die $current_path unless ref $data eq 'HASH';
		for my $key (keys %$data) {
			$self->_check_recursive(
				$data->{$key}, $markers,
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
		$markers{$def->name} = MARKER_LEAF;

		my $path = $def->get_name_path;
		my $path_meta = $path->meta;
		for my $ind (0 .. $#$path_meta) {
			if ($path_meta->[$ind] eq 'ARRAY') {
				$markers{$path->join($ind - 1)} = MARKER_ARRAY;
			}
		}
	}

	my $error = try sub {
		$self->_check_recursive($input, \%markers, Form::Tiny::Path->empty);
	};

	if ($error) {
		$obj->add_error($self->build_error(IsntStrict =>));
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

