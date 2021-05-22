package Form::Tiny::Hook;

use v5.10;
use warnings;
use Moo;
use Types::Standard qw(Enum CodeRef Bool);

use namespace::clean;

our $VERSION = '1.13';

use constant {
	HOOK_BEFORE_MANGLE => 'before_mangle',
	HOOK_BEFORE_VALIDATE => 'before_validate',
	HOOK_CLEANUP => 'cleanup',
};

my @hooks = (
	HOOK_BEFORE_MANGLE,
	HOOK_BEFORE_VALIDATE,
	HOOK_CLEANUP
);

has "hook" => (
	is => "ro",
	isa => Enum[@hooks],
	required => 1,
);

has "code" => (
	is => "ro",
	isa => CodeRef,
	required => 1,
);

has 'inherited' => (
	is => 'ro',
	isa => Bool,
	default => sub { 1 },
);

sub is_modifying
{
	my ($self) = @_;

	return $self->hook ne HOOK_CLEANUP;
}

1;
