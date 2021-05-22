use v5.10;
use warnings;
use Test::More;
use Form::Tiny;

{

	package TestForm;
	use Form::Tiny -base;

	form_field 'with_data' => (
		data => "data ok"
	);
}

my $form = TestForm->new;
is scalar @{$form->form_meta->resolved_fields($form)}, 1, "field defs ok";
ok $form->form_meta->resolved_fields($form)->[0]->has_data, "data ok";
is $form->form_meta->resolved_fields($form)->[0]->data, "data ok", "data ok";

done_testing();
