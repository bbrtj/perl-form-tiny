use v5.10;
use strict;
use warnings;

use Test::More;
use Test::Exception;

{
	package ParentForm;

	use Form::Tiny;
	form_field 'inherited_field';
}

{
	package ChildForm;

	use Form::Tiny;
	extends 'ParentForm';
};

lives_ok {
	my $obj = ChildForm->new;
	$obj->field_defs;
};

done_testing;

