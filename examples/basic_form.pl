use Modern::Perl "2010";
use Test::More;
use Data::Dumper;

{
	package RegistationForm;
	use Moo;
	use Types::Standard qw(Enum);
	use Types::Common::Numeric qw(IntRange);
	use Types::Common::String qw(SimpleStr StrongPassword StrLength);
	use Form::Tiny::Error;

	with "Form::Tiny";

	sub build_fields
	{
		my %password = (
			type => StrongPassword,
			required => 1,
		);

		{
			name => "username",
			type => SimpleStr & StrLength[4, 30],
			required => 1,
			adjust => sub { ucfirst shift },
		},

		{
			name => "password",
			%password,
		},

		{
			name => "repeat_password",
			%password,
		},

		# can be a full date with Types::DateTime
		{
			name => "year_of_birth",
			type => IntRange[1900, 1900 + (localtime)[5]],
			required => 1,
		},

		{
			name => "sex",
			type => Enum["male", "female", "other"],
			required => 1,
		}
	}

	sub build_cleaner
	{
		my ($self, $data) = @_;

		$self->add_error(
			Form::Tiny::Error::DoesNotValidate->new(error => "passwords are not identical")
		) if $data->{password} ne $data->{repeat_password};
	}

	1;
}

my $form = RegistationForm->new({
	username => "perl",
	password => "meperl-5",
	repeat_password => "meperl-5",
	year_of_birth => 1987,
	sex => "other",
});

ok ($form->valid, "Registration successful");

if (!$form->valid) {
	note Dumper($form->errors);
}

$form->input({
	%{$form->input},
	repeat_password => "eperl-55",
});

ok (!$form->valid, "passwords do not match");

note Dumper($form->errors);

done_testing();
