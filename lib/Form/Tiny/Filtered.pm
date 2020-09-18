package Form::Tiny::Filtered;

use v5.10; use warnings;
use Types::Standard qw(Str ArrayRef InstanceOf);

use Form::Tiny::Filter;

sub trim
{
	my ($value) = @_;
	$value =~ s/\A\s+//;
	$value =~ s/\s+\z//;

	return $value;
}

use Moo::Role;

requires qw(pre_mangle _clear_form);

has "filters" => (
	is => "ro",
	isa => ArrayRef [
		(InstanceOf ["Form::Tiny::Filter"])
		->plus_coercions(ArrayRef, q{ Form::Tiny::Filter->new($_) })
	],
	coerce => 1,
	default => sub {
		[shift->build_filters]
	},
	trigger => sub { shift->_clear_form },
	writer => "set_filters",
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

around "pre_mangle" => sub {
	my ($orig, $self, $def, $value) = @_;

	$value = $self->$orig($def, $value);
	return $self->_apply_filters($value);
};

1;
