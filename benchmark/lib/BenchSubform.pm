package BenchSubform;

use v5.10;
use strict;
use warnings;

{

	package BenchSubform::Subform;

	use Form::Tiny;
	use Types::Standard qw(Int);

	form_field 'x2' => (
		type => Int,
	);
}

use Form::Tiny;

form_field 'x1' => (
	type => BenchSubform::Subform->new,
);

sub name { 'typed.subform' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => {x2 => 55}},
		invalid => {x1 => {x2 => 'abc'}},
	};
}

1;

