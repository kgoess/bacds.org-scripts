#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getleaders.pl" -->
##
##
use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);
use DBI;

my $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $TEST_TODAY = $ENV{TEST_TODAY};

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments);
my ($today_year,$today_mon,$today_day,$today, $today_sec);
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($qrystr, $loc_qry, $loc_type);
my ($style, $venue, $numdays);
my ($styleurl, $danceurl);
my ($outputtype);
my (%leaderhash);
my @vals;
my @clst;
my ($i, $varname, $data);
my @monlst = (
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December"
);
my ($yr, $mon, $day);
my ($key, $hall, $addr, $city, $ven_comment);
my ($loc_hall, $loc_addr, $loc_city, $loc_ven_comment);

##
## Grab arguments
##
#@vals = split(/&/,$ENV{'QUERY_STRING'}) if $ENV{'QUERY_STRING'};
#foreach $i (@vals) {
#	($varname, $data) = split(/=/,$i);
#	$style = $data if $varname eq "style";
#	$venue = $data if $varname eq "venue";
#	$numdays = $data if $varname eq "numdays";
#	$outputtype = $data if $varname eq "outputtype";
#}

##
## First, get the current date.
##
($today_day, $today_mon, $today_year) = my_localtime();
$today_sec = timelocal(0,0,0,$today_day,$today_mon,$today_year);
$today_mon++;
$today_mon = "0$today_mon" if $today_mon < 10;
$today_day = "0$today_day" if $today_day < 10;
$today_year += 1900;
$today = "$today_year-$today_mon-$today_day";

if ($numdays) {
	##
	## Now figure out what the date will be in a week.
	##
	$last_sec = $today_sec + (86400 * 8);
	($last_day, $last_mon, $last_year) = (localtime($last_sec))[3,4,5];
	$last_mon++;
	$last_mon = "0$last_mon" if $last_mon < 10;
	$last_day = "0$last_day" if $last_day < 10;
	$last_year += 1900;
	$last = "$last_year-$last_mon-$last_day";

#print "Today is $today\n";
#print "It will be $last in $numdays days\n";
}

##
## Now build our query string
##
$qrystr = "SELECT * FROM schedule";
$qrystr .= " WHERE ";
$qrystr .= "startday >= '" . $today . "'";
$qrystr .= " AND startday < '" . $last . "'" if $numdays;
$qrystr .= " AND loc = '" . $venue . "'" if $venue;
$qrystr .= " AND type LIKE '%" . $style . "%'" if $style;
$qrystr .= " AND endday IS NULL";
$qrystr .= " AND leader IS NOT NULL";

#print "$qrystr\n";

##
## Set up the table and make the query
##
$dbh = get_dbh();
# get schedule info
$sth = $dbh->prepare($qrystr);
$sth->execute();

##
## Pull out caller names
##
#print "content-type: text/html\n\n";
while (($startday, $endday, $type, $loc, $leader, $band, $comments, $loc_type)
	 = $sth->fetchrow_array()
) {
	#
	# If leader has a location code, nuke it
	#
	$leader =~ s/ \[[^\]]+\].*//g;
	@clst = split(/, /, $leader);
	foreach $i (@clst) {
		$leaderhash{$i} = $i if ! $leaderhash{$i};
	}
}
#
# And print out our resulting leaders
print "<select name=\"caller\">\n";
print "    <option value=\"\">ALL LEADERS</option>\n";
foreach $i (sort keys %leaderhash) {
	print "    <option value=\"$i\">" . $i . "</option>\n";
}
print "</select>\n";

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

sub get_dbh {
    return DBI->connect(
        qq[DBI:CSV:f_dir=$CSV_DIR;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\], '', ''
    );
}
