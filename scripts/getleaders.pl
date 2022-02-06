#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getleaders.pl" -->
##
## note that this script doesn't look at QUERY_STRING

use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);
use DBI;

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
## Pull out caller names
##
my (%leaderhash);
foreach my $event (@events) {
    my $leader = $event->leader;
	#
	# If leader has a location code, nuke it
	#
	$leader =~ s/ \[[^\]]+\].*//g;
	my @clst = split(/, /, $leader);
	foreach my $i (@clst) {
		$leaderhash{$i} = $i if ! $leaderhash{$i};
	}
}
#
# And print out our resulting leaders
print "<select name=\"caller\">\n";
print "    <option value=\"\">ALL LEADERS</option>\n";
foreach my $i (sort keys %leaderhash) {
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

sub get_dbh {
    return DBI->connect(
        qq[DBI:CSV:f_dir=$CSV_DIR;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\], '', ''
    );
}
