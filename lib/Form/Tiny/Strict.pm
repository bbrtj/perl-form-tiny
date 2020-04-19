package Form::Tiny::Strict;

use Modern::Perl "2010";
use Moo::Role;
use Types::Standard qw(Bool);

requires qw(_clear_form);

has "strict" => (
	is => "rw",
	isa => Bool,
	builder => "build_strict",
	trigger => sub { shift->_clear_form },
);

sub build_strict { 1 }

no Moo::Role;
1;
