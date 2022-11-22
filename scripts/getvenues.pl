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
use bacds::Utils qw/today_ymd/;

our $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';

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
my $today = today_ymd();
my ($today_year, $today_mon, $today_day) = split '-', $today;

my $last;
if ($numdays) {
	##
	## Now figure out what the date will be in a week.
	##
	$last = DateTime
        ->new(year => $today_year, month => $today_mon, day => $today_day)
        ->add(days => 8)
        ->ymd;
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

