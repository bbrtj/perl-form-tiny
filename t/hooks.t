use v5.10; use warnings;
use Test::More;
use Data::Dumper;

BEGIN { use_ok('Form::Tiny') }

{

	package TestForm;
	use Moo;
	use Types::Standard qw(Int);

	with qw(
		Form::Tiny
		Form::Tiny::Filtered
	);

	sub build_fields
	{
		(
			{name => 'name.*', type => Int},
		)
	}

	sub pre_validate
	{
		my ($self, $input) = @_;

		if (ref $input->{name} eq ref []) {
			@{$input->{name}} = grep { defined } @{$input->{name}};
		}

		return $input;
	}

	sub pre_mangle
	{
		my ($self, $definition, $value) = @_;

		return $value . 1;
	}
}

my @data = (
	[1, {}, {}],
	[1, {name => [2, 3]}, {name => [21, 31]}],
	[1, {name => [0, undef, 3]}, {name => ["01", 31]}],
	[1, {name => [undef, undef, undef]}, {}],
	[0, {name => {}}],
);

for my $aref (@data) {
	my ($result, $input, $expected) = @$aref;

	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	if ($form->valid && $expected) {
		is_deeply $form->fields, $expected, "result values ok";
	}
	for my $error (@{$form->errors}) {
		is($error->field, "name.*", "error namespace valid");
	}

	note Dumper($input);
	note Dumper($form->errors);
}

done_testing();
