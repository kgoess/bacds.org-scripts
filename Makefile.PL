use 5.016003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME              => 'bacds',
    VERSION_FROM      => 'lib/bacds.pm', # finds $VERSION

    # The default "make install" only has two possible targets, "SCRIPT" and "BIN".
    # To make this work in that framework, we'll use SCRIPT for script/*.pl
    # and *.sh, and BIN for cgi-bin/*.cgi.
    INST_BIN => 'cgi-bin',
    INSTALLSITEBIN => '/var/www/bacds.org/cgi-bin/',

    INST_SCRIPT => 'scripts',
    INSTALLSITESCRIPT => '/var/www/bacds.org/public_html/scripts',

    PREREQ_PM         => {
        'Capture::Tiny' => 0.24,
        'CGI' => 3.63, # is in core
        'Class::Accessor::Lite' => 0.05,
        'Curses' => 1.28,
        'Curses::UI' => 0.9609,
        'Data::Dump' => 1.22,
        'Date::Calc' => 6.3,
        'Date::Day' => 1.04,
        'Date::Format' => 2.24,
        'DateTime' => 1.04,
        'DBI' => 1.627,
        'ExtUtils::MakeMaker' => 6.68,
        'Fcntl' => 1.11, # is in core
        'File::Basename' => 2.84, # File::* are are in core
        'File::Copy' => 2.23,
        'File::Path' => 2.09,
        'File::Temp' => 0.2301,
        'Getopt::Long' => 2.4, # is in core
        'HTML::Entities' => 3.69,
        'JSON' => 2.59,
        'Template' => 2.24,
        'Test::Differences' => 0.5,
        'Test::More' => 0.98,
        'Test::Output' => 1.01,
        'Time::Local' => 1.2300, # is in core
        'YAML' => 0.84,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/bacds.pm', # retrieve abstract from module
       AUTHOR         => 'Kevin M. Goess') : ()),
);

sub MY::postamble {
    return <<'MAKE_FRAG';

diff-with-prod:
	for f in scripts/*.pl scripts/*.sh ; do \
		diff -u /var/www/bacds.org/public_html/scripts/$$(basename $$f) $$f ; \
		/usr/bin/true; \
	done
	for f in cgi-bin/*.cgi cgi-bin/*.pl ; do \
		diff -u /var/www/bacds.org/cgi-bin/$$(basename $$f) $$f ; \
		/usr/bin/true; \
	done

MAKE_FRAG
}

