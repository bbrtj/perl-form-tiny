use Modern::Perl "2010";
use Test::More;
use Data::Dumper;
use lib 't/lib';

BEGIN { use_ok('TestForm') };

my @data = (
	[1, {nested => {name => "name"}}],
	[1, {nested => {name => {isa_hash => 1}}}],
	[1, {'not.nested' => 1}],
	# nested is not a hash
	[0, {nested => "test"}],
	[0, {not => {nested => "invalid"}}],
);

for my $aref (@data) {
	my ($result, $input) = @$aref;
	note Dumper($input);
	my $form = TestForm->new($input);
	is !!$form->valid, !!$result, "validation output ok";
	note Dumper($form->errors);
}

done_testing();
