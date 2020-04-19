use Modern::Perl "2010";
use Test::More;

BEGIN { use_ok('Form::Tiny') };

{
	package TestForm;
	use Moo;

	with "Form::Tiny";

	sub build_fields
	{
		{name => "arg", required => 1},
		{name => "arg2", required => 0}
	}

	1;
}

my @data = (
	[0, {}],
	[1, {arg => "test"}],
	[0, {arg => undef}],
	[0, {arg => ""}],
	[1, {arg => "0"}],
	[1, {arg => 22, arg2 => 15}],
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
			isa_ok($error, "Form::Tiny::Error::DoesNotExist");
		}
	}
}

done_testing();
