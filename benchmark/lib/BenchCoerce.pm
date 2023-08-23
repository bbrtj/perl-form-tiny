package BenchCoerce;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int Undef);

form_field 'x1' => (
	type => Int->plus_coercions(Undef, q{-1}),
	coerce => 1,
);

sub name { 'typed.coerce' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => undef},
	};
}

1;

