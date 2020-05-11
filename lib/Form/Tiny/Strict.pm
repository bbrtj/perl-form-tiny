package Form::Tiny::Strict;

use Modern::Perl "2010";
use Types::Standard qw(Bool);

use Form::Tiny::Error;
use Moo::Role;

requires qw(_clear_form field_defs add_error);

has "strict" => (
	is => "rw",
	isa => Bool,
	builder => "build_strict",
	trigger => sub { shift->_clear_form },
);

sub build_strict { 1 }

sub check_exists
{
	my ($self, $el, @keys) = @_;

	for my $key (@keys) {
		return 0 unless ref $el eq ref {};
		return 0 unless exists $el->{$key};
		$el = $el->{$key};
	}
	return 1;
}

sub count_recursive
{
	my ($self, $data, $skip, $path) = @_;
	$path //= [];

	return 1 if ref $data ne ref {} || $skip->{join $Form::Tiny::FieldDefinition::nesting_separator, @$path};
	my $total = 0;
	for my $key (keys %$data) {
		$total += $self->count_recursive($data->{$key}, $skip, [@$path, $key]);
	}
	return $total;
}

sub _check_strict
{
	my ($self, $input) = @_;

	my $total = 0;
	my %skip;
	foreach my $def (@{$self->field_defs}) {
		$total += $self->check_exists($input, $def->get_name_path);
		if ($def->has_type && $def->type->DOES("Form::Tiny::Form")) {
			$skip{$def->name} = 1;
		}
	}

	$self->add_error(Form::Tiny::Error::IsntStrict->new)
		if $total < $self->count_recursive($input, \%skip);
}

around "_pre_validate" => sub {
	my ($orig, $self, $input) = @_;

	$self->$orig($input);
	if ($self->strict) {
		$self->_check_strict($input);
	}
};

1;
