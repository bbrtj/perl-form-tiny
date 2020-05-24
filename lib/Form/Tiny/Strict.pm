package Form::Tiny::Strict;

use Modern::Perl "2010";
use Types::Standard qw(Bool);

use Form::Tiny::Error;
use Form::Tiny::FieldDefinition;
use Moo::Role;

use constant META_SKIP => "skip";
use constant META_ARRAY => "array";
use constant META_LEAF => "leaf";

requires qw(_clear_form field_defs add_error);

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
	$path //= [];

	my $current_path = Form::Tiny::FieldDefinition->join_path($path);
	my $metadata = $meta->{$current_path} // "";

	return if $metadata eq META_SKIP;

	if ($metadata eq META_LEAF) {
		# we're at leaf and no error occured - we're good.
	}

	elsif ($metadata eq META_ARRAY) {
		die $current_path unless ref $data eq ref [];
		foreach my $value (@$data) {
			$self->_check_recursive($value, $meta, [@$path, $Form::Tiny::FieldDefinition::array_marker]);
		}
	}

	else {
		# only leaves are allowed to be anything
		# on regular elements we expect a hashref
		die $current_path unless ref $data eq ref {};
		for my $key (keys %$data) {
			$self->_check_recursive($data->{$key}, $meta, [@$path, $key]);
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
		} else {
			$meta{$def->name} = META_LEAF;
		}

		if ($def->want_array) {
			my @path = $def->get_name_path;
			for my $i (0 .. $#path) {
				my $el = $path[$i];
				if ($el eq $Form::Tiny::FieldDefinition::array_marker) {
					my @current_path = @path[0 .. $i - 1];
					$meta{Form::Tiny::FieldDefinition->join_path(\@current_path)} = META_ARRAY;
				}
			}
		}
	}

	local $@;
	eval { $self->_check_recursive($input, \%meta) };
	if ($@) {
		$self->add_error(Form::Tiny::Error::IsntStrict->new);
	}
}

around "_pre_validate" => sub {
	my ($orig, $self, $input) = @_;

	$self->$orig($input);
	if ($self->strict) {
		$self->_check_strict($input);
	}
};

1;
