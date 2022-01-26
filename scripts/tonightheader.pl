#!/usr/bin/perl -w
##
## Determine whether there are any dances tonight (today's date)
## and emit an H1 header followed by a div class=tonight if there are;
## if not, no header, and a tagless div.
##
## current usage:
##
## public_html/scripts/make-frontpage-files.sh:REQUEST_METHOD="" QUERY_STRING="numdays=1&outputtype=INLINE" perl scripts/tonightheader.pl > tonight.html
## public_html/scripts/make-tonight-file.sh:perl scripts/tonightheader.pl outputtype=INLINE > tonight.html
##
##

use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);
use Date::Day;
use DBI;
use CGI;

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments);
my ($st_day, $st_mon, $st_yr, $end_day, $end_mon, $end_yr);
my ($today_year,$today_mon,$today_day,$today, $today_sec);
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($qrystr, $cqrystr, $qrydif, $loc_qry, $loc_type);
my ($style, $venue, $numdays);
my ($styleurl, $danceurl, $dburl, $stdloc, $plural);
my ($outputtype, $muso, $qmuso, $caller, $qcaller);
my @vals;
my ($i, $varname, $data);
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


$outputtype = $data if (defined($varname) && $varname eq "outputtype");

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
$numdays = 1;

if ($numdays) {
            ##
            ## Now figure out what the date will be tomorrow
            ##
            $last_sec = $today_sec + (86400 * $numdays);
            ($last_day, $last_mon, $last_year) = (localtime($last_sec))[3,4,5];
            $last_mon++;
            $last_mon = "0$last_mon" if $last_mon < 10;
            $last_day = "0$last_day" if $last_day < 10;
            $last_year += 1900;
            $last = "$last_year-$last_mon-$last_day";
    
    }

##
## Now build our query string
##
$cqrystr = "SELECT COUNT(*) FROM schedule";
#
$qrydif .= " WHERE startday = '" . $today . "'";
$qrydif .= " AND startday < '" . $last . "'" if ($numdays > 1);

$cqrystr .= $qrydif;
#print STDERR "tonightheader.pl:  ", $cqrystr, "\n";

##
## Set up the table and make the query
##
$dbh = DBI->connect(qq[DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');
# get number of rows
$sth = $dbh->prepare($cqrystr);
$sth->execute();
($numrows) = $sth->fetchrow_array();

if ($numrows) {
    ($numrows == 1) ? $plural = " " : $plural = "s";
    
		  
}

##
## Print out results
##
#print "content-type: text/html\n\n";
if (!$outputtype || ($outputtype && ($outputtype !~ /inline/i))) {
	print <<ENDHTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xthml1-strict.dtd">
<html>
<head>
<title>Dance tonight</title>
ENDHTML
	open(METAFILE,"<$meta_file") || die "can't open $meta_file: $!";
	print while <METAFILE>;
	close(METAFILE);
	print <<ENDHTML;
<link rel="stylesheet" title="base" type="text/css" href="/css/base.css" />
</head>
<body index="scriptoutput">
<h1>
ENDHTML
	print "\n</h1>\n";

}
if ($numrows) {
    print "<h2>Today's Dance$plural!</h2>\n";
# print "<table border><tr><td>\n";
# NHC -- Think semantic markup -vs- relying on side effects from an unnecessary
#	 presentation tag to get the effect that you want.
# and look for "div.tonight" style in /css/base.css for styling
    print '<div class="tonight">', "\n";
} else {
    print '<div>', "\n";
}    
    
if (!$outputtype || ($outputtype && ($outputtype !~ /inline/i))) {
	print <<ENDHTML;
</body>
</html>
ENDHTML
}

