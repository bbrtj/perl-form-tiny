package BenchNoType;

use v5.10;
use strict;
use warnings;

use Form::Tiny;

form_field 'x1' => (
	required => 1,
);

sub name { 'untyped' }
sub category { 'features' }

sub cases
{
	return {
		valid => {x1 => 55},
		invalid => {},
	};
}

1;

