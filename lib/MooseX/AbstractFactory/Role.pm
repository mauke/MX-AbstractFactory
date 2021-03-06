package MooseX::AbstractFactory::Role;
use strict;
use warnings;
use Moose::Role;

use Module::Runtime qw( use_package_optimistically );
use Try::Tiny;

# VERSION

our $AUTHORITY = 'cpan:PENFOLD';

has _options        => (is => 'ro', isa => 'ArrayRef[Any]');
has _implementation => (is => 'ro', isa => 'Str');

sub create {
	my ($class, $impl, @impl_args) = @_;

	if (defined $impl) {
		my $factory
			= $class->new({
				_implementation => $impl,
				_options => [ @impl_args ]
			});

		my $iclass
			= $factory->_get_implementation_class(
				$factory->_implementation()
			);

		# pull in our implementation class
		$factory->_validate_implementation_class($iclass);

		my $iconstructor = $iclass->meta->constructor_name;

		my $implementation
			= $iclass->$iconstructor(
				@{ $factory->_options }
			);

		# TODO - should we sneak a factory attr onto the metaclass?
		return $implementation;
	}
	else {
		confess('No implementation provided');
	}
}

sub _get_implementation_class {
	my ($self, $impl) = @_;

	my $class = blessed $self;
	if ($self->meta->has_class_maker) {
		return $self->meta->implementation_class_maker->($impl);
	}
	else {
		return $class . "::$impl";
	}
}

sub _validate_implementation_class {
	my ($self, $iclass) = @_;

	try {
		# can we load the class?
		use_package_optimistically($iclass); # may die if user really stuffed up _get_implementation_class()

		if ($self->meta->has_implementation_roles) {
			my $roles = $self->meta->implementation_roles();

			# create an anon class that's a subclass of it
			my $anon = Moose::Meta::Class->create_anon_class();

			# make it a subclass of the implementation
			$anon->superclasses($iclass);

			# Lifted from MooseX::Recipe::Builder->_build_anon_meta()

			# load our role classes
			use_package_optimistically($_) for @$roles;

			# apply roles to anon class
			if (scalar @{$roles} == 1) {
				$roles->[0]->meta->apply($anon);
			}
			else {
				Moose::Meta::Role->combine(map { $_->meta } @$roles)->apply($anon);
			}
		}
	}
	catch {
		confess "Invalid implementation class $iclass: $_";
	};

	return;
}

1;
# ABSTRACT: AbstractFactory behaviour as a Moose extension

=head1 SYNOPSIS

You shouldn't be using this on its own, but via MooseX::AbstractFactory

=head1 DESCRIPTION

Role to implement an AbstractFactory as a Moose extension.


=method create()

Returns an instance of the requested implementation.

	use MooseX::AbstractFactory;

	my $imp = My::Factory->create(
		'Implementation',
		{ connection => 'Type1' },
	);

=method _validate_implementation_class()

Optional: it provides the methods defined in _roles().

This can be overridden by a factory class definition if required: for example

	sub _validate_implementation_class {
		my $self = shift;
		return 1; # all implementation classes are valid :)
	}


=method _get_implementation_class()

By default, the factory figures out the class of the implementation requested
by prepending the factory class itself, so for example

	my $imp = My::Factory->new(
		implementation => 'Implementation')

will return an object of class My::Factory::Implementation.

This can be overridden in the factory class by redefining the
_get_implementation_class() method, for example:

	sub _get_implementation_class {
		my ($self, $class) = @_;
		return "My::ImplementationClasses::$class";
	}

=head1 BUGS AND LIMITATIONS

No bugs have been reported. Yet.

Please report any bugs or feature requests to C<mike@altrion.org>, or via RT.

=head1 ACKNOWLEDGMENTS

Thanks to Matt Trout for some of the ideas for the code in
_validate_implementation_class.

=cut
