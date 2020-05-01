use Modern::Perl "2010";
use Test::More;
use Data::Dumper;

BEGIN { use_ok('Form::Tiny') };

{
	package TestForm;
	use Moo;
	use Types::Common::String qw(SimpleStr);

	with "Form::Tiny", "Form::Tiny::Strict";

	sub build_fields
	{
		{name => "name.first_name", type => SimpleStr},
		{name => "name.last_name"},
	}

	1;
}

my @data = (
	[1, {name => {first_name => "name", last_name => "surname"}}],
	[1, {name => {last_name => {isa_hash => 1}}}],
	# name is not a hash
	[0, {name => "test"}],
	# name.first_name is a hash, and we wanted Str
	[0, {name => {first_name => {isa_hash => 1}}}],
	# value is not declared as a field, and we're strict
	[0, {value => 5}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	note Dumper($form->errors);
}

done_testing();
