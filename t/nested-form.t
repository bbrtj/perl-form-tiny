use Modern::Perl "2010";
use Test::More;
use Data::Dumper;

BEGIN { use_ok('Form::Tiny') };

{
	package InnerForm;
	use Moo;
	use Types::Common::String qw(SimpleStr);

	with "Form::Tiny", "Form::Tiny::Strict";

	sub build_fields
	{
		{
			name => "nested",
			type => SimpleStr,
			required => 1
		},
	}

	1;
}

{
	package OuterForm;
	use Moo;

	with "Form::Tiny";

	sub build_fields
	{
		{name => "form", type => InnerForm->new},
	}
}

my @data = (
	[1, {form => {nested => "asdf"}}],
	[1, {}],
	# nested form is strict
	[0, {form => {nested => "a string", more => 1}}],
	# nested field needs to validate as well
	[0, {form => {nested => []}}],
	# nested field is required
	[0, {form => {}}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	my $form = OuterForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	note Dumper($form->errors);
}

done_testing();
