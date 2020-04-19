use 5.010000;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'Form::Tiny',
	VERSION_FROM => 'lib/Form/Tiny.pm',
	MIN_PERL_VERSION => '5.010',

	TEST_REQUIRES => {
		'Test::Exception' => "0",
	},

	PREREQ_PM => {
		"Modern::Perl" => "0",
		"Moo" => "0",
		"Type::Tiny" => "0",
		"Text::Trim" => "0",
	},

	META_MERGE => {
		resources => {
			license => 'https://dev.perl.org/licenses',
			homepage => 'https://metacpan.org/release/Form-Tiny',
			bugtracker => 'https://github.com/brtastic/perl-form-tiny/issues',
			repository => 'https://github.com/brtastic/perl-form-tiny',
		},
	},

	ABSTRACT_FROM => 'lib/Form/Tiny.pm',
	AUTHOR => 'bartosz <bartosz@(none)>',
	LICENSE => 'perl',
);
