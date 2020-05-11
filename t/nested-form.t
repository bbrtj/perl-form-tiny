use Modern::Perl "2010";
use Test::More;
use Data::Dumper;
use lib 't/lib';

BEGIN { use_ok('TestForm') };

my @data = (
	[1, {nested_form => {int => 5}}],
	[1, {nested_form => {int => 0}}],
	[1, {}],
	# nested form is strict
	[0, {nested_form => {int => 0, more => 1}}],
	# nested field needs to validate as well
	[0, {nested_form => {int => "int"}}],
	# nested field is required
	[0, {nested_form => {}}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	note Dumper($form->errors);
}

done_testing();
