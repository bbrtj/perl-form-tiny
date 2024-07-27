package Form::Tiny::Plugin::Strict;

use v5.10;
use strict;
use warnings;

use Form::Tiny::Error;

use parent 'Form::Tiny::Plugin';

sub plugin
{
	my ($self, $caller, $context) = @_;

	return {
		meta_roles => [__PACKAGE__],
	};
}

use Moo::Role;

requires qw(setup);

# cache for the blueprint (if non-dynamic)
has '_strict_blueprint' => (
	is => 'rw',
);

sub _check_recursive
{
	my ($self, $data, $blueprint, $path ) = @_;
	return 0 unless defined $blueprint;

	my $ref = ref $blueprint;

	if ($ref eq 'ARRAY') {
		return 0 unless ref $data eq 'ARRAY';

                my $idx;
		foreach my $value (@$data) {
                        my @lpath = ( @{$path}, $idx++ );
                        if ( ! $self->_check_recursive($value, $blueprint->[0], \@lpath) ) {
                            @{$path} = @lpath;
                            return 0;
                        }
		}
	}
	elsif ($ref eq 'HASH') {
		return 0 unless ref $data eq 'HASH';

		for my $key (keys %$data) {
                        my @lpath = ( @{$path}, $key );
                        if ( !  $self->_check_recursive($data->{$key}, $blueprint->{$key}, \@lpath) ) {
                            @{$path} = @lpath;
                            return 0;
                    }
		}
	}
	else {
		# we're at leaf and no error occured - we're good.
	}

	return 1;
}

sub _check_strict
{
	my ($self, $obj, $input) = @_;

	my $blueprint = $self->_strict_blueprint;
	if (!$blueprint) {
		$blueprint = $self->blueprint($obj, recurse => 0);
		$self->_strict_blueprint($blueprint)
			unless $self->is_dynamic;
	}

        my @unexpected_field;
	my $strict = $self->_check_recursive($input, $blueprint, \@unexpected_field);
	if (!$strict) {
                my $field = join( q{.}, @unexpected_field);
                my $error = $self->build_error(IsntStrict => );
                $error->set_error( $error->error . ': ' . $field )
                  if length($field);
		$obj->add_error($error);
	}

	return $input;
}

after 'setup' => sub {
	my ($self) = @_;

	$self->add_hook(
		Form::Tiny::Hook->new(
			hook => 'before_validate',
			code => sub { $self->_check_strict(@_) },
			inherited => 0,
		)
	);
};

1;

