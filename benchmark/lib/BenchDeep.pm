package BenchDeep;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int Str);

form_field 'a.*.b' => (
	type => Int,
	required => 1,
);

form_field 'a.*.c' => (
	type => Str,
	required => 1,
);

sub name { 'typed.nested' }
sub category { 'stress' }

sub cases
{
	return {
		valid => {
			a => [
				map {
					{
						b => 55,
						c => 'abc'
					}
				} 1 .. 20
			],
		},
		invalid => {
			a => [
				(
					map {
						{
							b => 55,
							c => 'abc'
						}
					} 1 .. 19
				),
				{
					b => '55g',
					c => 'abc',
				}
			],
		},
	};
}

1;

