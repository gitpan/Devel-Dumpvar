require 5.000;
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'Devel::Dumpvar',
	'VERSION_FROM' => 'lib/Devel/Dumpvar.pm',
	'PREREQ_PM'    => {
		# Needed for module
		Scalar::Util => 1.11,

		# Needed for test scripts
		File::Spec => 0.82,
		Test::More => 0,
	},
	($] >= 5.005) ? (
		'AUTHOR'   => 'Adam Kennedy (cpan@ali.as)',
		'ABSTRACT' => 'Pure OO re-implementation of dumpvar.pl',
	) : (),
);
