use v5.10;
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Data::Dumper;

{
	package TestForm;

	use Form::Tiny;

	has 'name_part' => (
		is => 'ro',
	);

	form_field 'static';
	form_field sub {
		my ($self) = @_;

		return {
			name => 'dynamic_' . $self->name_part,
		};
	};
}

my $form = TestForm->new(name_part => 'field');

sub fdef
{
	my ($name) = @_;

	for my $def (@{$form->field_defs}) {
		return $def if $def->name eq $name;
	}

	die "Unknown field name: $name";
}

my $expected = {
	static => fdef('static'),
	dynamic_field => fdef('dynamic_field'),
};

dies_ok {
	TestForm->form_meta->blueprint;
};

dies_ok {
	TestForm->form_meta->static_blueprint;
};

is_deeply($form->form_meta->blueprint($form), $expected, 'dynamic blueprint structure ok');
note Dumper(TestForm->form_meta->blueprint($form));

done_testing;

