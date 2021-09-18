use v5.10;
use warnings;
use Test::More;

{
	package TestForm;
	use Form::Tiny -filtered;
	use Types::Standard qw(Str);

	form_field 'f1';
	field_filter Str, sub { shift() . '+'};

	form_field 'f2';

	form_filter Str, sub { shift() . '!' };
}

my @data = (
	[{f1 => 5}, {f1 => '5!+'}],
	[{f1 => 'aa'}, {f1 => 'aa!+'}],
	[{f2 => 5}, {f2 => '5!'}],
);

my $form = TestForm->new;
for my $aref (@data) {
	$form->set_input($aref->[0]);
	ok $form->valid, "no error detected";
	is_deeply $form->fields, $aref->[1], "value correctly filtered";
}

done_testing();
