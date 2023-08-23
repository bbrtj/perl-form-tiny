package BenchHooks;

use v5.10;
use strict;
use warnings;

use Form::Tiny;
use Types::Standard qw(Int);

form_field 'x1' => (
	type => Int,
);

form_hook before_validate => sub {
	my ($self, $input) = @_;

	$input->{x1} //= $input->{xn};
};

sub name { 'typed.hook' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => 55},
		invalid => {x1 => 'abc'},
	};
}

1;

