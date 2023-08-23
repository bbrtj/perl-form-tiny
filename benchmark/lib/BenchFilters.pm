package BenchFilters;

use v5.10;
use strict;
use warnings;

use Form::Tiny -filtered;
use Types::Standard qw(Int);

form_field 'x1' => (
	type => Int,
);

field_filter Int, sub {
	return pop() * 2;
};

sub name { 'typed.filter' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => 55},
		invalid => {x1 => 'abc'},
	};
}

1;

