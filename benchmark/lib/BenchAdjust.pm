package BenchAdjust;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field 'x1' => (
	type => Int,
	adjust => sub { pop() * 2 },
);

sub name { 'typed.adjust' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => 55},
	};
}

1;

