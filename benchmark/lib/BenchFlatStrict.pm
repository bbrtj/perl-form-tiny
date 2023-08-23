package BenchFlatStrict;

use v5.10;
use strict;
use warnings;

use Form::Tiny -strict;
use Types::Standard qw(Int);

form_field 'x1' => (
	type => Int,
);

sub name { 'typed.strict' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => 55},
		invalid => {x1 => 55, x2 => 55},
	};
}

1;

