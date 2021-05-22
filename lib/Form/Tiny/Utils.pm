package Form::Tiny::Utils;

use v5.10;
use warnings;
use Exporter qw(import);

our $VERSION = '1.13';
our @EXPORT;
our @EXPORT_OK = qw(
	try
	trim
);

sub try
{
	my ($sub) = @_;

	local $@;
	my $ret = not eval {
		$sub->();
		return 1;
	};

	if ($@ && $ret) {
		$ret = $@;
	}

	return $ret;
}

sub trim
{
	my ($value) = @_;
	$value =~ s/\A\s+//;
	$value =~ s/\s+\z//;

	return $value;
}


1;
