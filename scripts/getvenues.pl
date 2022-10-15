#!/usr/bin/perl -w
##
## Get list of venues
##
## dancefinder/content.html <!--#include virtual="/scripts/getvenues.pl" -->
#
use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);

use bacds::Model::Event;
use bacds::Model::Venue;

our $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
our $TEST_TODAY = $ENV{TEST_TODAY};

my ($style, $venue, $numdays);
my (%venuehash);

##
## Grab arguments
##
my @vals = split(/&/,$ENV{'QUERY_STRING'}) if $ENV{'QUERY_STRING'};
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
my $today_sec = timelocal(0,0,0,$today_day,$today_mon,$today_year);
$today_mon++;
$today_mon = sprintf "%02d", $today_mon;
$today_day = sprintf "%02d", $today_day;
$today_year += 1900;
my $today = "$today_year-$today_mon-$today_day";

my $last;
if ($numdays) {
	##
	## Now figure out what the date will be in a week.
	##
	my $last_sec = $today_sec + (86400 * 8);
	my ($last_day, $last_mon, $last_year) = (localtime($last_sec))[3,4,5];
	$last_mon++;
	$last_mon = sprintf "%02d", $last_mon;
	$last_day = sprintf "%02d", $last_day;
	$last_year += 1900;
	$last = "$last_year-$last_mon-$last_day";

}


my @events = bacds::Model::Event->load_all(
    after => $today,
    ($numdays ? (before => $last) : ()),
    venue => $venue,
    style => $style,
    includes_leader => 1,
    without_end_date => 1,
);

foreach my $event (@events) {
    my $loc = $event->loc;
	my ($norm_venue, $norm_city) = get_hall_name_city($loc);
	$venuehash{$loc} = $norm_city . " -- " . $norm_venue if ! $venuehash{$loc};
}
#
print "<select name=\"venue\">\n";
print "    <option value=\"\">ALL LOCATIONS</option>\n";
foreach my $i (sort keys %venuehash) {
	print "    <option value=\"$i\">" . $venuehash{$i} . "</option>\n";
}
print "</select>\n";

sub get_hall_name_city {
	my ($vkey) = @_;

    if (my $venue = bacds::Model::Venue->load(vkey => $vkey)) {
        return $venue->hall, $venue->city;
    }
    return();
}

sub my_localtime {
    if ($TEST_TODAY) {
        my ($year, $mon, $day) = split '-', $TEST_TODAY;
        $mon--;
        if ($mon < 0) {
            $mon = 11;
        }
        $year -= 1900;
        return $day, $mon, $year;
    } else {
        my ($today_day, $today_mon, $today_year) = (localtime)[3,4,5];
        return $today_day, $today_mon, $today_year;
    }
}
