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

sub _check_strict
{
	my ($self, $input) = @_;

	my $total = 0;
	foreach my $def (@{$self->field_defs}) {
		$total += defined $input->{$def->name} ? 1 : 0;
	}

	$self->add_error(Form::Tiny::Error::IsntStrict->new)
		if $total < scalar keys %$input;
}

1;
