#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getstyles.pl" -->
##
## This includes camps (where endday IS NOT null)
use strict;
use DateTime;

use bacds::Model::Event;

my $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $TEST_TODAY = $ENV{TEST_TODAY};

##
## Grab arguments
##
my @vals = split(/&/,$ENV{'QUERY_STRING'}) if $ENV{'QUERY_STRING'};
my ($style, $venue, $numdays);
foreach my $i (@vals) {
	my ($varname, $data) = split(/=/,$i);
	$style = $data if $varname eq "style";
	$venue = $data if $varname eq "venue";
	$numdays = $data if $varname eq "numdays";
}

##
## First, get the current date.
##
my ($today_day, $today_mon, $today_year) = my_localtime();
my $today = "$today_year-$today_mon-$today_day";

my $last;
if ($numdays) {
	##
	## Now figure out what the date will be in a week.
	##
	$last = DateTime
        ->new(year => $today_year, month => $today_mon, day => $today_day)
        ->add(days => 8)
        ->ymd;

#print "Today is $today\n";
#print "It will be $last in $numdays days\n";
}

my @events = bacds::Model::Event->load_all(
    after => $today,
    before => $last, # optional
    venue => $venue, # optional
    style => $style, # optional
    without_end_date => 0,
    includes_leader => 1,
);

my %stylehash = ();
foreach my $event (@events) {
    my $type = $event->type;

	my $temp_type;
	$temp_type = $type;
	$temp_type = 'SPECIAL' if $type =~ /SPECIAL/;
	$temp_type = 'WOODSHED' if $type =~ /WOODSHED/;
	$temp_type = 'CAMP' if $type =~ /CAMP/;
	$stylehash{$temp_type} = 
        $temp_type if (! $stylehash{$type} );
}
#
# And print out our resulting styles
print "<select name=\"style\">\n";
print "    <option value=\"\">ALL STYLES</option>\n";
foreach my $i (sort keys %stylehash) {
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

