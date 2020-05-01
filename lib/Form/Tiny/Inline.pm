package Form::Tiny::Inline;

use Modern::Perl "2010";
use Moo;
use Types::Standard qw(ArrayRef RoleName Str);

use namespace::clean;

with "Form::Tiny";

has "roles" => (
	is => "ro",
	isa => ArrayRef[
		RoleName->plus_coercions(Str, q{ my $n = "Form::Tiny::$_"; eval "require $n"; $n; })
	],
	coerce => 1,
	init_arg => "is",
	predicate => 1,
);

sub BUILD
{
	my ($self, $args) = @_;

	if ($self->has_roles) {
		require Moo::Role;
		Moo::Role->apply_roles_to_object($self, @{$self->roles});
	}
}

sub build_fields {}

1;
