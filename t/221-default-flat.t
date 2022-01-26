use v5.10;
use strict;
use warnings;
use Test::More;
use Form::Tiny::Inline;
use Test::Exception;
use Types::Standard qw(Int);

{

	package TestForm;
	use Types::Standard qw(Undef);
	use Form::Tiny -base;

	form_field 'undefined' => (
		type => Undef,
		default => sub { undef },
	);

	form_field 'default' => (
		default => sub { 5 },
	);
}

my @data = (
	[{default => 3}, {default => 3}],
	[{default => "0"}, {default => "0"}],
	[{default => ""}, {default => ""}],
	[{default => undef}, {default => undef}],
	[{}, {default => 5}],
);

my $form = TestForm->new;

for my $aref (@data) {
	$form->set_input($aref->[0]);
	ok $form->valid, "no error detected";
	is_deeply $form->fields, {%{$aref->[1]}, undefined => undef}, "default value ok";
}

for my $conf ({name => 'a.*.b'}, {name => 'aoeu.*'}, {name => 'test', type => Int}) {
	dies_ok {
		my $form = Form::Tiny::Inline->new(
			field_defs => [
				{
					default => sub { 'def' },
					%$conf,
				}
			],
		);
		$form->set_input({});
		$form->valid;
	}
	'invalid form configuration dies';
}

done_testing();
