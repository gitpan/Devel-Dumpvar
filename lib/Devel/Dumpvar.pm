package Devel::Dumpvar;

# Devel::Dumpvar is a pure-OO re-implementation of the dumpvar.pl
# script used with the perl debugger.
# This module accepts that this will be slower than the original,
# but is designed to be easier to use, more accessible, and more
# upgradable without upgrading perl itself.

use 5.005;
use strict;
use UNIVERSAL 'isa';
use Scalar::Util ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.02';
}





#####################################################################
# Constructor and Accessors

sub new {
	my $class = ref $_[0] ? shift : shift;
	my %options = @_;

	# Create the basic object
	my $self = bless {}, $class;

	# Handle the various options
	if ( defined $options{to} ) {
		$self->to( $options{to} );
	}

	$self;
}

sub to {
	my $self = shift;

	# Just return if no argument
	return $self->{to} unless @_;

	# If passed undef, print to STDOUT
	my $to = shift;
	unless ( defined $to ) {
		delete $self->{to};
		delete $self->{return};
		return 1;
	}

	# Is it something we can print to
	if ( ref $to and UNIVERSAL::can( $to, 'print' ) ) {
		$self->{to} = $to;
		return 1;
	}

	# Handle the magic 'return' option
	if ( ! ref $to and $to eq 'return' ) {
		$self->{to}     = 'return';
		return 1;
	}

	# Unknown option
	die "Unknown value '$to' for 'to' options";
}





#####################################################################
# Dumping Methods

# Single method dumping
sub dump {
	my $self = ref $_[0] ? shift : shift->new;

	# Set up for dumping
	$self->{indent} = '';
	$self->{seen}   = {};
	$self->{return} = '' if $self->_return;

	if ( @_ ) {
		# Hand off to the array dumper
		$self->_dump_array( [ @_ ] );
	} else {
		# Shortcut the "no arguments" case
		$self->_print( "   empty array");
	}

	# Clean up and return the data if needed
	delete $self->{indent};
	delete $self->{seen};
	$self->_return ? delete $self->{return} : 1;
}

sub _dump_scalar {
	my $self = shift;
	my $value = isa( $_[0], 'SCALAR' ) ? shift
		: die "Bad argument to _dump_scalar";

	# Print the printable form of the scalar
	$self->_print( "$self->{indent}-> " . $self->_scalar($$value) );
}

sub _dump_ref {
	my $self = shift;
	my $value = isa( $_[0], 'REF' ) ? ${shift()}
		: die "Bad argument to _dump_array";

	# Print the current line
	$self->_print( "$self->{indent}-> " . $self->_refstring($value) );

	# Decend to the child reference
	$self->_dump_child( $value );
}

sub _dump_array {
	my $self = shift;
	my $array_ref = isa( $_[0], 'ARRAY' ) ? shift
		: die "Bad argument to _dump_array";

	# Handle the null array
	unless ( @$array_ref ) {
		return $self->_print( $self->{indent} . "  empty array" );
	}

	for ( my $i = 0; $i <= $#$array_ref; $i++ ) {
		my $value = $array_ref->[$i];

		# Handle scalar values
		unless ( ref $value ) {
			# Get the printable form of the scalar
			$self->_print( "$self->{indent}$i  " . $self->_scalar($value) );
			next;
		}

		# Print the array line
		$self->_print( "$self->{indent}$i  " . $self->_refstring($value) );

		# Descend to the child
		$self->_dump_child( $value );
	}
}

sub _dump_hash {
	my $self = shift;
	my $hash_ref = isa( $_[0], 'HASH' ) ? shift
		: die "Bad argument to _dump_hash";

	foreach ( sort keys %$hash_ref ) {
		my $key   = $self->_scalar( $_ );
		my $value = $hash_ref->{$_};

		# Handle scalar values
		unless ( ref $value ) {
			# Get the printable form of the scalar
			$self->_print( "$self->{indent}$key => " . $self->_scalar($value) );
			next;
		}

		# Print the array line
		$self->_print( "$self->{indent}$key => " . $self->_refstring($value) );

		# Decent to the child
		$self->_dump_child( $value );
	}
}

sub _dump_code {
	my $self = shift;
	my $value = isa( $_[0], 'CODE' ) ? shift
		: die "Bad argument to _dump_code";

	$self->_print( "$self->{indent}-> Sub detail listing unsupported" );
}

sub _dump_child {
	my $self = shift;
	my $value = ref $_[0] ? shift
		: die "Bad argument to _dump_child";

	# Regexp are a special case, they are immune
	# from the normal re-used address rules
	if ( ref $value eq 'Regexp' ) {
		# Print the pointer to the regexp
		return $self->_print( "$self->{indent}   -> qr/$value/" );
	}

	# Handle re-used addresses
	my $addr = Scalar::Util::refaddr $value;
	if ( $self->{seen}->{$addr}++ ) {
		# We've already seen this before
		return $self->_print( "$self->{indent}   -> REUSED_ADDRESS" );
	}

	# Indent to descend
	$self->{indent} .= '   ';

	# Split by type for the remaining items
	my $type = Scalar::Util::reftype $value;
	if ( $type eq 'REF' ) {
		$self->_dump_ref( $value );
	} elsif ( $type eq 'SCALAR' ) {
		$self->_dump_scalar( $value );
	} elsif ( $type eq 'ARRAY' ) {
		$self->_dump_array( $value );
	} elsif ( $type eq 'HASH' ) {
		$self->_dump_hash( $value );
	} elsif ( $type eq 'CODE' ) {
		$self->_dump_code( $value );
	} else {
		die "ARRAY -> $type not supported";
	}

	# Remove indent
	$self->{indent} =~ s/   $//;
}





#####################################################################
# Support Methods

# Get the display string for a scalar value
sub _scalar {
	my $self = shift;
	my $value = shift;

	# Shortcuts
	return 'undef' unless defined $value;
	return "''" unless length $value;

	# Is it a number?
	if ( Scalar::Util::looks_like_number( $value ) ) {
		# Show as-is
		return $value;
	}

	# Escape the scalar
	### FINISH THIS

	"'" . $value . "'";
}

sub _refstring {
	my $self = shift;
	my $value = ref $_[0] ? shift
		: die "Bad argument to _refstring";

	# Handle regexp
	if ( ref $value eq 'Regexp' ) {
		return "$value";
	}

	my $addr  = sprintf '0x%x', Scalar::Util::refaddr($value);
	my $type  = Scalar::Util::reftype($value);
	unless ( $type =~ /^(?:SCALAR|ARRAY|HASH|REF|CODE)$/ ) {
		return "UNSUPPORTED($addr)";
	}
	my $class = Scalar::Util::blessed($value);
	defined $class
		? "$class=$type($addr)"
		: "$type($addr)";
}

sub _print {
	my $self = shift;
	my $line = defined $_[0] ? "$_[0]\n" : "\n";

	# Handle the default case
	return print $line unless $self->{to};

	if ( $self->{to} eq 'return' ) {
		# Handle the "return data" case
		$self->{return} .= $line;

	} elsif ( UNIVERSAL::can( $self->{to}, 'print' ) ) {
		# If we have a we something we can print to, do so
		$self->{to}->print( $line );

	} else {
		# If the dump target is unknown, do nothing
	}

	1;
}

# Are we returning the dump data
sub _return {
	my $self = shift;
	defined $self->{to} and ! ref $self->{to} and $self->{to} eq 'return';
}

1;

__END__

=pod

=head1 NAME

Devel::Dumpvar - A pure-OO reimplementation of dumpvar.pl

=head1 SYNOPSIS

  use Devel::Dumpvar;
  
  # Dump something immediately to STDOUT
  Devel::Dumpvar->dump( [ 'foo' ], $bar' );
  
  # Create a dump handle to use repeatedly
  my $Dump = Devel::Dumpvar->new;
  
  # Dump via the handler
  $Dump->dump( 'foo', [ 'bar' ] );

=head1 DESCRIPTION

Most perl dumping modules are focused on serializing data structures
into a format that can be rebuilt into the original data structure.
They do this with a variety of different focuses, such as human
readability, the ability to execute the dumped code directly, or
to minimize the size of the dumped data.

Expect for the one contained in the debugger, in the file dumpvar.pl.
This is a readily human-readable form, highly useful for debugging,
containing a lot of extra information without the burden of needing to
be re-assembled into the original data.

The main downside of the dumper in the perl-debugger is that the
dumpvar.pl script is not really a readily loadable and useable module.
It has dedicated hooks from and to the debugger, and spans across
multiple namespaces, including main::.

Devel::Dumpvar is a pure object-orientated implementation of the
same functionality. This makes it much more usable version to use
for dumping information to debug log files or other uses where you
don't need to reassemble the data.

=head1 METHODS

=head2 new( option => value, ... )

The C<new> constructor creates a new dumping object. Any options can
be passed a list of key/value pairs.

Each option passed to the constructor is set via one of the option
methods below.

=head2 to( $output_destination )

The C<to> option specifies where the output is to be sent to. When
undefined, output will go to STDOUT. The output destination can be
either a handle object ( or anything else with a ->print method ),
or the string 'return', which will cause the C<dump> method to collect
and return the dump results for each call, rather than printing it
immediately to the output.

If called without an argument, returns the current value.
If called with an argument, returns true or dies on error.

=head2 dump( data1, data2, ... )

If called as an object method, dumps a number of data values or structs
to the dumping object. If called as a class method, creates a new
default dump object and immediately dumps to it, destroying the dumper
afterwards.

=head1 TO DO

  - Implement options currently available in other dumpers as needed.
  
  - Currently only supports SCALAR, REF, ARRAY, HASH and Regexp.
    Add support for all possible reference types.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel%3ADumpvar>

For other issues, contact the author

=head1 AUTHORS

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
