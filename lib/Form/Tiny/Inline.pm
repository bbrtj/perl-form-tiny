package Form::Tiny::Inline;

use v5.10; use warnings;
use Moo;
use Types::Standard qw(RoleName Str);

use namespace::clean;

with "Form::Tiny";

sub is
{
	my ($class, @roles) = @_;

	my $loader = q{ my $n = "Form::Tiny::$_"; eval "require $n"; $n; };
	my $type = RoleName->plus_coercions(Str, $loader);
	@roles = map { $type->assert_coerce($_) } @roles;

	require Moo::Role;
	return Moo::Role->create_class_with_roles($class, @roles);
}

sub build_fields {}

1;
