package BenchDynamic;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field sub {
	my ($self) = @_;

	return {
		name => 'x1',
		type => Int,
	};
};

sub name { 'typed.dynamic' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => 55},
		invalid => {x1 => 'abc'},
	};
}

1;

