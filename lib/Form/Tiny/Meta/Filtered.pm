package Form::Tiny::Meta::Filtered;

use v5.10;
use warnings;
use Types::Standard qw(ArrayRef InstanceOf);

use Form::Tiny::Hook;
use Form::Tiny::Filter;
use Moo::Role;

our $VERSION = '1.14';

requires qw(setup);

has "filters" => (
	is => "ro",
	writer => 'set_filters',
	isa => ArrayRef [
		InstanceOf ["Form::Tiny::Filter"]
	],
	default => sub { [] },
);

sub add_filter
{
	my ($self, $filter, $code) = @_;

	if (defined blessed $filter && $filter->isa('Form::Tiny::Filter')) {
		push @{$self->filters}, $filter;
	}
	else {
		push @{$self->filters}, Form::Tiny::Filter->new(
			type => $filter,
			code => $code
		);
	}

	return $self;
}

sub _apply_filters
{
	my ($self, $obj, $def, $value) = @_;

	for my $filter (@{$self->filters}) {
		$value = $filter->filter($value);
	}

	return $value;
}

after 'inherit_from' => sub {
	my ($self, $parent) = @_;

	if ($parent->DOES('Form::Tiny::Meta::Filtered')) {
		$self->set_filters([@{$parent->filters}, @{$self->filters}]);
	}
};

after 'setup' => sub {
	my ($self) = @_;

	$self->add_hook(
		Form::Tiny::Hook->new(
			hook => 'before_mangle',
			code => sub { $self->_apply_filters(@_) },
			inherited => 0,
		)
	);
};

1;

__END__

=head1 NAME

Form::Tiny::Filtered - early filtering for form fields

=head1 SYNOPSIS

	# in your form class
	use Form::Tiny -filtered;

	# optional - only trims strings by default
	form_filter Int, sub { abs shift() };

=head1 DESCRIPTION

This is a role which is meant to be mixed in together with L<Form::Tiny> role. Having the filtered role enriches Form::Tiny by adding a filtering mechanism which can change the field value before it gets validated.

The filtering system is designed to perform a type check on field values and only apply a filtering subroutine when the type matches.

By default, adding this role to a class will cause all string to be filtered with C<< Form::Tiny::Filtered->trim >>. Specifying the I<build_filters> method explicitly will override that behavior.

=head1 ADDED INTERFACE

=head2 ATTRIBUTES

=head3 filters

Stores an array reference of L<Form::Tiny::Filter> objects, which are used during filtering.

B<writer:> I<set_filters>

=head2 METHODS

=head3 trim

Built in trim functionality, to avoid dependencies. Returns its only argument trimmed.

=head3 build_filters

Just like build_fields, this method should return an array of elements.

Each of these elements should be an instance of Form::Tiny::Filter or an array reference, in which the first element is the type and the second element is the filtering code reference.
