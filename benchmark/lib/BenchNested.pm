package BenchNested;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field 'x1.x2' => (
	type => Int,
);

sub name { 'typed.nested_hash' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => {x2 => 55}},
		invalid => {x1 => {x2 => 'abc'}},
	};
}

1;

