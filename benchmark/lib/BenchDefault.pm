package BenchDefault;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field 'x1' => (
	type => Int,
	default => sub { 55 },
);

sub name { 'typed.default' }
sub category { 'features' }

sub cases
{
	return {
		valid => {},
	};
}

1;

