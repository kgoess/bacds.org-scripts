#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getleaders.pl" -->
##
## note that this script doesn't look at QUERY_STRING
#
## Set TEST_CSV_DIR in your environment to use something else
## besides '/var/www/bacds.org/public_html/data'.

use strict;

use bacds::Model::Event;
use bacds::Utils qw/today_ymd/;

my @events = bacds::Model::Event->load_all(
    after => today_ymd(),
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

