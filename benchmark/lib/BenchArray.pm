package BenchArray;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field 'x1.*' => (
	type => Int,
);

sub name { 'typed.nested_array' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => [55]},
		invalid => {x1 => ['abc']},
	};
}

sub run_bench
{
	my ($class) = @_;

}

1;

