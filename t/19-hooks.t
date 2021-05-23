use v5.10;
use warnings;
use Test::More;
use Data::Dumper;

{

	package TestForm;
	use Form::Tiny -filtered;
	use Types::Standard qw(Int);

	form_trim_strings;

	form_field 'name.*' => (
		type => Int
	);

	form_hook 'before_validate' => sub {
		my ($self, $input) = @_;

		if (ref $input->{name} eq ref []) {
			@{$input->{name}} = grep { defined } @{$input->{name}};
		}

		return $input;
	};

	form_hook 'after_validate' => sub {
		my ($self, $input) = @_;

		$input->{no_data} = 1
			if !$input->{name} || !scalar @{$input->{name}};
	};

	form_hook 'before_mangle' => sub {
		my ($self, $definition, $value) = @_;

		return $value . 1;
	};
}

my @data = (
	[1, {}, {no_data => 1}],
	[1, {name => [2, 3]}, {name => [21, 31]}],
	[1, {name => [0, undef, 3]}, {name => ["01", 31]}],
	[1, {name => [" 2 "]}, {name => ["21"]}],
	[1, {name => [undef, undef, undef]}, {name => [], no_data => 1}],
);

for my $aref (@data) {
	my ($result, $input, $expected) = @$aref;

	my $form = TestForm->new(input => $input);
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
