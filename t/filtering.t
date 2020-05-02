use Modern::Perl "2010";
use Test::More;
use Types::Standard qw(Int);

BEGIN {
	use_ok('Form::Tiny::Inline');
	use_ok('Form::Tiny::Filtered');
};

my $form = Form::Tiny::Inline->is(qw(Filtered))->new(
	field_defs => [{name => "test"}],
	filters => [[Int, sub { abs(shift) }]],
);

my @data = (
	[{test => 5}, {test => 5}],
	[{test => -1}, {test => 1}],
	[{test => -99999}, {test => 99999}],
	[{test => 0}, {test => 0}],
	[{test => -0.5}, {test => -0.5}],
	[{test => "abc"}, {test => "abc"}],
	[{test => "-1abc"}, {test => "-1abc"}],
);

for my $aref (@data) {
	$form->set_input($aref->[0]);
	ok $form->valid, "no error detected";
	is_deeply $form->fields, $aref->[1], "value correctly filtered";
}

done_testing();
