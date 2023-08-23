#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

use Benchmark qw(timethese);
use List::Util qw(max);
use Getopt::Long;

use lib 'lib';
use lib 'benchmark/lib';

my @benchmarks = qw(
	BenchCoerce
	BenchCoerceSub
	BenchFlat
	BenchNoType
	BenchNested
	BenchArray
	BenchSubform
	BenchFlatStrict
	BenchNestedStrict
	BenchAdjust
	BenchDefault
	BenchSubformDefault
	BenchDeep
	BenchFilters
	BenchHooks
	BenchDynamic
);

my $single = undef;
my $category = 'features';
my $time = 2;
GetOptions(
	'single=s' => \$single,
	'category=s' => \$category,
	'time=s' => \$time,
);

my %cases;
foreach my $bench (@benchmarks) {
	require "$bench.pm";
	my $name = $bench->name;
	my $bench_cases = $bench->cases;
	my $bench_category = $bench->category;

	if (!defined $single) {
		next unless $bench_category eq $category || $category eq 'all';
	}

	foreach my $case (keys %$bench_cases) {
		my $valid = $case !~ m/invalid/;

		next if defined $single && $name ne $single;

		my $form = $bench->new;
		$cases{"$bench_category ($case)"}{$name} = sub {
			$form->set_input($bench_cases->{$case});
			die "error in $name" if !$form->valid != !$valid;
		};
	}
}

# special benchmarking instead of cmpthese to keep it short horizontally
sub bench_and_print
{
	my ($cases) = @_;

	my $raw = timethese - 1 * $time, $cases, 'none';
	my @results = sort {
		$a->[1] <=> $b->[1]
	} map {
		[$_, int($raw->{$_}[-1] / $raw->{$_}[1])]
	} keys %$raw;

	my $longest = max map { length $_->[0] } @results;
	my $last = undef;
	foreach my $res (@results) {
		my $last_perc = '-';
		if (defined $last) {
			$last_perc = int(($res->[1] / $last - 1) * 100) . '%';
		}
		printf "%-${longest}s\t%d/s\t%s\n", @{$res}, $last_perc;
		$last = $res->[1];
	}
}

foreach my $case_type (sort keys %cases) {
	print "Benchmarking type: $case_type\n";
	print "-----------------------------\n";

	bench_and_print($cases{$case_type});
	print "\n";
}

__END__

=pod

These benchmarks are meant for measuring relative performance of various parts
of the system. Form::Tiny is very configurable, which means there are too many
moving parts to keep track of without automation. The aim is to have a way to
measure speed of features in isolation (category C<features>) as well as more
complex cases (category C<stress>).

