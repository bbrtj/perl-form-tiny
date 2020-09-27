use v5.10; use warnings;
use Test::More;
use Form::Tiny;

{

	package TestForm;
	use Moo;
	use Types::Common::String qw(StrLength LowerCaseStr);
	use Types::Common::Numeric qw(IntRange);

	with "Form::Tiny";

	sub build_fields
	{
		(
			{
				name => "string",
				type => StrLength [1, 10] &LowerCaseStr,
			},

			{
				name => "integer",
				type => (IntRange [2, 8])->where(q{ $_ % 2 == 0 }),
			}
		)
	}

	1;
}

my @data = (
	[1, {}],
	[1, {string => "string (1)", integer => 8}],
	[1, {string => 4, integer => "4"}],
	[0, {string => undef}],
	[0, {string => ''}],
	[0, {string => "a" x 11}],
	[0, {string => "Aaa"}],
	[0, {integer => 1}],
	[1, {integer => 2}],
	[0, {integer => 9}],
	[0, {integer => "integer"}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	if ($form->valid) {
		for my $field (keys %$input) {
			is defined $form->fields->{$field}, defined $input->{$field},
				"definedness for `$field` ok";
			is $form->fields->{$field}, $input->{$field}, "value for `$field` ok";
		}
	}
	else {
		for my $error (@{$form->errors}) {
			isa_ok($error, "Form::Tiny::Error::DoesNotValidate");
		}
	}
}

done_testing();
