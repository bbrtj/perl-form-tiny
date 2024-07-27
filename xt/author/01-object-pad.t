use v5.10;
use strict;
use warnings;
use Test::More;

BEGIN {
	my $has_object_pad = eval {
		require Object::Pad;
		Object::Pad->VERSION('0.57');
		Object::Pad->import;
		1;
	};

	plan skip_all => 'these tests require Object::Pad 0.57'
		unless $has_object_pad;
}

class ParentForm : repr(HASH)
{
	use Form::Tiny -nomoo;

	form_field 'f1';
}

class ChildForm : isa(ParentForm) : repr(HASH)
{
	use Form::Tiny -nomoo;

	form_field 'f2';
}

my $form = ChildForm->new;
$form->set_input(
	{
		f1 => 'field f1',
		f2 => 'field f2',
	}
);

ok $form->valid;
can_ok $form, 'form_meta';
is $form->fields->{f1}, 'field f1';
is $form->fields->{f2}, 'field f2';

done_testing;

