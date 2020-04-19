package Form::Tiny::Filtered;

use Modern::Perl "2010";
use Moo::Role;
use Types::Standard qw(Str ArrayRef InstanceOf);
use Text::Trim;

use Form::Tiny::Filter;

requires qw(_clear_form);

has "filters" => (
	is => "rw",
	isa => ArrayRef[
		(InstanceOf["Form::Tiny::Filter"])
			->plus_coercions(ArrayRef, q{ Form::Tiny::Filter->new($_) })
	],
	coerce => 1,
	default => sub {
		[ shift->build_filters ]
	},
	trigger => sub { shift->_clear_form },
);

sub build_filters
{
	[Str, \&trim]
}

sub _apply_filters
{
	my ($self, $value) = @_;

	for my $filter (@{$self->filters}) {
		$value = $filter->filter($value);
	}

	return $value;
}

no Moo::Role;
1;
