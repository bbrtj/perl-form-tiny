package BenchSubformDefault;

use v5.10;
use strict;
use warnings;

{

	package BenchSubformDefault::Subform;

	use Form::Tiny;
	use Types::Standard qw(Int);

	form_field 'x2' => (
		type => Int,
		default => sub { 55 },
	);
}

use Form::Tiny;

form_field 'x1' => (
	type => BenchSubformDefault::Subform->new,
	default => sub { {} },
);

sub name { 'typed.subform_default' }
sub category { 'features' }

sub cases
{
	return {
		valid => {},
	};
}

1;

