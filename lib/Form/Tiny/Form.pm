package Form::Tiny::Form;

use v5.10; use warnings;
use Moo::Role;

our $VERSION = '1.00';

requires qw(validate check);

1;
