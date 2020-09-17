use v5.10; use warnings;
use Test::More;
use Data::Dumper;
use lib 't/lib';

BEGIN { use_ok('TestForm') };

my @data = (
	[1, {nested => {name => "name"}}],
	[1, {'not.nested' => 1}],
	# unwanted nested hashes are VALID (use types if they're not)
	[1, {nested => {name => {isa_hash => 1}}}],
	# nested is not a hash
	[0, {nested => "test"}],
	[0, {not => {nested => "invalid"}}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	note Dumper($input);
	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	if ($form->valid && $result) {
		is_deeply $form->fields, $input, "hash contents ok";
	}
	note Dumper($form->errors);
}

done_testing();
