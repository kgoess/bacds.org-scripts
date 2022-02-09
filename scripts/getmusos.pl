#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getmusos.pl" -->
##
## getmusos.pl ignores QUERY_STRING
##
## getmusos.pl is buggy, the data in "band" includes all kinds of text trash,
## so the output of this includes all kinds of trash, like this:
##
##    <option value="Dance 2:30">Dance 2:30</option>
##
## 'musos" should be a separate table, many-to-one

use strict;

use DateTime;

use bacds::Model::Event;

my $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $TEST_TODAY = $ENV{TEST_TODAY};


##
## First, get the current date.
##
my ($today_day, $today_mon, $today_year) = my_localtime();
my $today = "$today_year-$today_mon-$today_day";

my @events = bacds::Model::Event->load_all(
    after => $today,
    without_end_date => 1,
    includes_leader => 1,
);
##
##
## Pull out band and muso names
##
my (%bandhash, %musohash);

foreach my $event (@events) {
    my $band = $event->band;
	my $guest = "";
	my $mstr = "";
	my $bandname = "";
	$_ = $band;
	s/ \[[^\]]+\]//g;			# Remove location
	s/ with /, /g;				# ' with ' same as ', ' 
	s/ and Friend[s]*//g;			# remove 'and Friend[s]'
	s/Open Band led by //;			# remove "Open Band"
	s/, and /, /;				# ' and ' same as ', '
	s/ and /, /;				# ' and ' same as ', '
	s/TBA//;				# remove "TBA"
	s/\<a.*\<q\>\>//;			# remove opening "<a>"
	s/\<\\a\>//;				# remove closing "<\a>"
	$band = $_;
#	print "Transformed line:  " . $band . "\n";
	#
	# We've removed and cleaned up the cruft.  Now let's try to 
	#  parse out the goodies.
	#
	# At this point, we have one of:
	#
	#	muso, muso, muso, ...
	#	band (muso ...)
	#	band (muso ...), guest
	$mstr = $_;
	($bandname,$mstr,$guest) = /(.+) \((.+)\), (.+)/ if /\),/;
	($bandname,$mstr) = /(.+) \((.+)\)/ if /\)$/;
	$mstr = $_ if ! /\)/;
#	print "Parsed line:  ";
#	print "bandname=$bandname	" if $bandname;
#	print "mstr=$mstr	" if $mstr;
#	print "guest=$guest	" if $guest;
#	print "\n";
	#
	# We should be parsed now.  Now build our lists.
	#
	my @mlst = split(/, /,$mstr);
	foreach my $i (@mlst) {
		$musohash{$i} = $i if ! $musohash{$i};
	}
	$bandhash{$bandname} = $bandname if $bandname;
	$musohash{$guest} = $guest if ($guest && ! $musohash{$guest});
}
#
# Manually insert open band
#
$bandhash{"Open Band"} = "Open Band";
#
# And print out our resulting bands and musicians
print "<select name=\"muso\">\n";
print "    <option value=\"\">ALL BANDS AND MUSICIANS</option>\n";
foreach my $i (sort keys %bandhash) {
	print "    <option value=\"$i\">" . $i . "</option>\n";
}
print "    <option value=\"\"></option>\n";
foreach my $i (sort keys %musohash) {
	print "    <option value=\"$i\">" . $i . "</option>\n";
}
print "</select>\n";


sub my_localtime {
    if ($TEST_TODAY) {
        my ($year, $mon, $day) = split '-', $TEST_TODAY;
        return $day, $mon, $year;
    } else {
        my $now = DateTime->now;
        return map { $now->$_ } qw/day month year/;
    }
}

