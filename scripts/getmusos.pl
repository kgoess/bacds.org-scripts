#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getmusos.pl" -->
##
##
use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);
use DBI;

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments);
my ($today_year,$today_mon,$today_day,$today, $today_sec);
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($qrystr, $loc_qry, $loc_type);
my ($style, $venue, $numdays);
my ($styleurl, $danceurl);
my ($outputtype);
my ($bandname, $mstr, $guest);
my (%bandhash, %musohash);
my @vals;
my @mlst;
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
($today_day, $today_mon, $today_year) = (localtime)[3,4,5];
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
$dbh = DBI->connect(qq[DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');
# get schedule info
$sth = $dbh->prepare($qrystr);
$sth->execute();

##
## Pull out band and muso names
##
#print "content-type: text/html\n\n";
while (($startday,$endday,$type,$loc,$leader,$band,$comments,$loc_type) = $sth->fetchrow_array()) {
	$guest = "";
	$mstr = "";
	$bandname = "";
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
	@mlst = split(/, /,$mstr);
	foreach $i (@mlst) {
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
foreach $i (sort keys %bandhash) {
	print "    <option value=\"$i\">" . $i . "</option>\n";
}
print "    <option value=\"\"></option>\n";
foreach $i (sort keys %musohash) {
	print "    <option value=\"$i\">" . $i . "</option>\n";
}
print "</select>\n";