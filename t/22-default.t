use v5.10;
use warnings;
use Test::More;
use Form::Tiny::Inline;
use Test::Exception;
use Types::Standard qw(Int);

{

	package TestForm;
	use Form::Tiny -base;

	form_field 'undefined' => (
		default => sub { undef },
	);

	form_field 'default' => (
		default => sub { 5 },
	);

	form_field 'nested.default' => (
		default => sub { ['test'] },
		required => 1,
	);
}

my @data = (
	[{default => 3, nested => {default => 3}}, {default => 3, nested => {default => 3}}],
	[{default => "0", nested => {default => "0"}}, {default => "0", nested => {default => '0'}}],
	[{default => "", nested => {default => ""}}, {default => "", nested => {default => ['test']}}],
	[{default => undef, nested => {default => undef}}, {default => undef, nested => {default => ['test']}}],
	[{}, {default => 5, nested => {default => ['test']}}],
	[{nested => {}}, {default => 5, nested => {default => ['test']}}],
);

my $form = TestForm->new;

for my $aref (@data) {
	$form->set_input($aref->[0]);
	ok $form->valid, "no error detected";
	is_deeply $form->fields, {%{$aref->[1]}, undefined => undef}, "default value ok";
}

for my $conf ({name => 'a.*.b'}, {name => 'aoeu.*'}, {name => 'test', type => Int}) {
	dies_ok {
		Form::Tiny::Inline->new(
			field_defs => [
				{
					default => 'def',
					%$conf,
				}
			],
		);
	}
	'invalid form configuration dies';
}

done_testing();
