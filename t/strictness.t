use Modern::Perl "2010";
use Test::More;

BEGIN {
	use_ok('Form::Tiny');
	use_ok('Form::Tiny::Strict');
};

{
	package TestForm;
	use Moo;

	with "Form::Tiny",
		"Form::Tiny::Strict";

	sub build_fields
	{
		{name => "arg"}
	}

	1;
}

my @data = (
	[1, {}],
	[1, {arg => "test"}],
	[0, {arg => 22, arg2 => 15}],
	[0, {arg2 => "more data"}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	if ($form->valid) {
		for my $field (keys %$input) {
			is $form->fields->{$field}, $input->{$field}, "value for `$field` ok";
		}
	} else {
		for my $error (@{$form->errors}) {
			isa_ok($error, "Form::Tiny::Error::IsntStrict");
		}
	}
}

done_testing();
