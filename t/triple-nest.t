use Modern::Perl "2010";
use Test::More;
use Data::Dumper;

BEGIN { use_ok('Form::Tiny::Inline') };

my $form = Form::Tiny::Inline->is(qw(Strict))->new(
	field_defs => [{name => "one.two.three"}],
	input => {one => {two => {three => 3}}},
);

ok ($form->valid, "validation ok");
is ($form->fields->{one}{two}{three}, 3, "value ok");

$form->input({one => {two => 2}});

ok (!$form->valid, "invalid form validation ok");

done_testing;
