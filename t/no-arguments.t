use Modern::Perl "2010";
use Test::More;

BEGIN { use_ok('Form::Tiny') };

{
	package TestForm;
	use Moo;

	with "Form::Tiny";

	sub build_fields
	{
		{name => "name"},
		{name => "value"}
	}

	1;
}

my @data = (
	[{},],
	[{name => "me"},],
	[{name => "you", value => "empty"},],
	[{value => "something"},],
	[{more => "more"}, {"more" => 1}],
	[{name => undef},],
);

# test for invalid format rejection
for my $input ([], 0, "", "a", \1, sub {}) {
	my $form = TestForm->new($input);
	ok !$form->valid, "non-hashref is not accepted";
	my $errors = $form->errors;
	is scalar @$errors, 1, "only one error reported";
	isa_ok shift @$errors, "Form::Tiny::Error::InvalidFormat",
		"error type matches";
}

for my $aref (@data) {
	my ($input, $ignore) = @$aref;
	my $form = TestForm->new($input);
	ok $form->valid, "validation output ok";
	for my $field (keys %$input) {
		if (!defined $ignore || !$ignore->{$field}) {
			is defined $form->fields->{$field}, defined $input->{$field}, "definedness for `$field` ok";
			is $form->fields->{$field}, $input->{$field}, "value for `$field` ok";
		}
	}
}

done_testing();
