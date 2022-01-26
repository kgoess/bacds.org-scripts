#!/usr/bin/perl -wT
##
## Find out what dances are happening in the next week.
##
##
use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);
use DBI;
use CGI;

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments);
my ($today_year,$today_mon,$today_day,$today, $today_sec);
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($qrystr, $cqrystr, $qrydif, $loc_qry, $loc_type);
my ($style, $venue, $numdays);
my ($styleurl, $danceurl);
my ($outputtype, $muso, $qmuso, $caller, $qcaller);
my @vals;
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
my $menu_file = '/var/www/bacds.org/public_html/shared/menu.html';
my $meta_file = '/var/www/bacds.org/public_html/shared/meta-tags.html';
my $footer_file = '/var/www/bacds.org/public_html/shared/copyright.html';
my $argstr;
my $value;
my $numrows;
my $q = new CGI;

##
## Grab arguments
##
## Arguments/variables are:
##
##	style -- dance style
##	venue -- dance venue
##	numdays -- number of days we should report for
##	outputtype -- type of output
##	caller -- caller at dance
##	muso -- musical staff
##
#@vals = split(/&/,$ENV{'QUERY_STRING'}) if $ENV{'QUERY_STRING'};
#foreach $i (@vals) {
#	($varname, $data) = split(/=/,$i);
#	$style = $data if $varname eq "style";
#	$venue = $data if $varname eq "venue";
#	$numdays = $data if $varname eq "numdays";
#	$outputtype = $data if $varname eq "outputtype";
#	$muso = $data if $varname eq "muso";
#	$caller = $data if $varname eq "caller";
#}
#if ($caller) {
#	$_ = $caller;
#	s/\+/ /g;
#	s/%27/'/g;
#	$caller = $_;
#}
#if ($style) {
#	$_ = $style;
#	s/\+/ /g;
#	$style = $_;
#}
#if ($muso) {
#	$_ = $muso;
#	s/\+/ /g;
#	s/%27/'/g;
#	$muso = $_;
#}

foreach $varname ($q->param) {
	$data = "";
	foreach $value ($q->param($varname)) {
		$data .= " " . $value if $data;
		$data = $value if !$data;
	}
	$style = $data if $varname eq "style";
	$venue = $data if $varname eq "venue";
	$numdays = $data if $varname eq "numdays";
	$outputtype = $data if $varname eq "outputtype";
	$muso = $data if $varname eq "muso";
	$caller = $data if $varname eq "caller";
}

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
$cqrystr = "SELECT COUNT(*) FROM schedule";
#
$qrydif .= " WHERE startday >= '" . $today . "'";
$qrydif .= " AND startday < '" . $last . "'" if $numdays;
$qrydif .= " AND loc = '" . $venue . "'" if $venue;
$qrydif .= " AND type LIKE '%" . $style . "%'" if $style;
if ($caller) {
	$_ = $caller;
	s/'.+//g;
	$qcaller = $_;
}
$qrydif .= " AND leader LIKE '%" . $qcaller . "%'" if $qcaller;
if ($muso) {
	$_ = $muso;
	s/'.+//g;
	$qmuso = $_;
}
$qrydif .= " AND band LIKE '%" . $qmuso . "%'" if $qmuso;
$qrydif .= " AND endday IS NULL";
$qrydif .= " AND leader IS NOT NULL";

$qrystr .= $qrydif;
$cqrystr .= $qrydif;

print STDERR "$qrystr\n";

##
## Set up the table and make the query
##
$dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');
# get number of rows
$sth = $dbh->prepare($cqrystr);
$sth->execute();
($numrows) = $sth->fetchrow_array();

if ($numrows) {
	# get schedule info
	$sth = $dbh->prepare($qrystr);
	$sth->execute();
}

##
## Print out results
##
print "content-type: text/html\n\n";
if (!$outputtype || ($outputtype && ($outputtype !~ /inline/i))) {
	print <<ENDHTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xthml1-strict.dtd">
<html>
<head>
<title>Results from dancefinder query</title>
ENDHTML
	open(METAFILE,"<$meta_file") || die "can't open $meta_file: $!";
	print while <METAFILE>;
	close(METAFILE);
	print <<ENDHTML;
<link rel="stylesheet" title="base" type="text/css" href="/css/base.css" />
</head>
<body>
<h1>
ENDHTML
	print ucfirst(lc($style)) . " " if $style;
	print "Dances";
	if ($venue) {
		($loc_hall, $loc_city) = get_hall_name_city($venue);
		print " At " . $loc_hall . " in " . $loc_city . "--" . $type;
	}
	if ($caller) {
		print " Led By " . $caller;
	}
	if ($muso) {
		print " Featuring " . $muso;
	}
	if ($numdays) {
		print " During The Next " . $numdays;
		($numdays == 1) ? print " Day" : print " Days";
	}
	print "\n</h1>\n";

}
if ($numrows) {
	while (($startday,$endday,$type,$loc,$leader,$band,$comments,$loc_type) = $sth->fetchrow_array()) {
		# Skip special events
		# next if $type =~ /SPECIAL/;
		# Get style URL
		$styleurl = "http://www.bacds.org/series/contra/"
		    if $type =~ /CONTRA/;
		$styleurl = "http://www.bacds.org/series/english/"
		    if $type =~ /ENGLISH/;
		$styleurl = "http://www.bacds.org/series/ceilidh/"
		    if $type =~ /CEILIDH/;
	
		# Get dance URL
		$danceurl = $styleurl . get_event_url($startday,$type,$loc);

		# Adjust date
		($yr,$mon,$day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
		$day =~ s/^0//g if $day < 10;
		$mon =~ s/^0//g if $mon < 10;

		# Get location information
		$loc_dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');
		$loc_qry = "SELECT * FROM venue";
		$loc_qry .= " WHERE vkey = '" . $loc . "'";
		$loc_sth = $loc_dbh->prepare($loc_qry);
		$loc_sth->execute();
		while (($key, $hall, $addr, $city, $ven_comment) = $loc_sth->fetchrow_array()) {
			$loc_hall = $hall;
			$loc_addr = $addr;
			$loc_city = $city;
			$loc_ven_comment = $ven_comment;
		}

		# And print the thing
		print "<p class=\"listing\">\n";
		print $monlst[$mon-1] . " " . $day;
		print ": <a href=\"" . $styleurl . "\">" . $type . "</a>";
		print " at ";
		print "<a href=\"" . $danceurl . "\">";
		print $loc_hall;
		print " in " . $loc_city . "</a>.  ";
		print $leader . " with " . $band . "\n";
		print "</p>\n";

#"<a href=\"$danceurl\">$startday</a> <a href=\"$styleurl\">$type</a>	$loc $leader with $band <br />\n";
	}
	print "</p>\n";
} else {
	print "<p class=\"listing\">\n";
	print "There are no upcoming dances that meet your criteria.\n";
	print "</p>\n";
}
if (!$outputtype || ($outputtype && ($outputtype !~ /inline/i))) {
	print <<ENDHTML;
</body>
</html>
ENDHTML
}

sub get_event_url {
	my ($date, $type, $loc) = @_;
	my @day_list = ("sun","mon","tue","wed","thu","fri","sat");
	my ($yr, $mon, $day);
	my ($wday);
	my ($wdayname);
	my $eventurl = undef;

	## The following data structure maps venues that host only one
	## event to the sub-URL that they correspond to.
	my %url_map = (
		'PSS' => 'berkeley_fri/',
		'BET' => 'san_francisco/',
		'SF' => 'san_francisco/',
		'MT' => 'palo_alto/',
		'PA' => 'palo_alto/',
		'STA' => 'palo_alto/',
		'ECV' => 'el_cerrito/',
		'FLX' => 'mountain_view/',
		'CRO' => 'berkeley_wed/',
	);

	## And pick the low-lying fruit.
	if ($url_map{$loc}) {
		$eventurl = $url_map{$loc};
	}

	## If $eventurl is not defined at this point, sort out what it is.
	if (!defined($eventurl)) {
		# Grace North Church should be the only location at this point.
		if ($loc eq "GNC") {
			# Only one CONTRA and CEILIDH series uses the hall
			$eventurl = "berkeley_sun/" if $type eq "CEILIDH";
			$eventurl = "berkeley_wed/" if $type eq "CONTRA";

			# If type is ENGLISH, we need to know the day of the
			# week
			if ($type eq "ENGLISH") {
				## Get the day of week
				($yr, $mon, $day) =
				    ($date =~ /(\d+)-(\d+)-(\d+)/);
				$wday = Day_of_Week($yr, $mon, $day);
				$eventurl = "berkeley_wed/"
				    if $wday == 3;
				$eventurl = "berkeley_sat/"
				    if $wday == 6;
			}
		}
	}
	## Return the event
	$eventurl;
}

sub get_hall_name_city {
	my ($venue) = @_;
	my ($dbh, $qry, $sth);
	my ($hall, $city);
	my ($loc_hall, $loc_city);

	# Get location information
	$dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');
	$qry = "SELECT hall, city FROM venue";
	$qry .= " WHERE vkey = '" . $venue . "'";
	$sth = $dbh->prepare($qry);
	$sth->execute();
	while (($hall, $city) = $sth->fetchrow_array()) {
		$loc_hall = $hall;
		$loc_city = $city;
	}
	($loc_hall, $loc_city);
}
