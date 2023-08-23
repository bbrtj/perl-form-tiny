package BenchCoerceSub;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field 'x1' => (
	type => Int,
	coerce => sub {
		my $value = pop;
		return $value // -1;
	},
);

sub name { 'typed.coerce_sub' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => undef},
	};
}

1;

