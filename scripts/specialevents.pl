#!/usr/bin/perl -w
##
## Find out what special events are coming up.
##
## public_html/scripts/make-frontpage-files.sh:perl scripts/specialevents.pl > specialevents.html
##
use strict;
use Time::Local;
use DBI;
use Date::Day;

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments, 
    $name, $stdloc, $dburl, $dbtime);
my ($today_year,$today_mon,$today_day,$today, $today_sec);
my ($qrystr, $loc_qry);
my @mon_lst = (
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

my %day_lst = ('MON' => 'Monday',
               'TUE' => 'Tuesday',
               'WED' => 'Wednesday',
               'THU' => 'Thursday',
               'FRI' => 'Friday',
               'SAT' => 'Saturday',
               'SUN' => 'Sunday' );
    

my ($st_yr, $st_mon, $st_day);
my ($end_yr, $end_mon, $end_day);
my ($key, $hall, $addr, $city, $ven_comment);
my ($loc_hall, $loc_addr, $loc_city, $loc_ven_comment);

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

#print "Today is $today\n";

##
## Now build our query string
##
$qrystr = "SELECT * FROM schedule";
$qrystr .= " WHERE ( ( endday >= '" . $today . "'  ";
$qrystr .= " OR  startday >= '" . $today . "' ) ";
$qrystr .= " AND ( type LIKE '%CAMP%' OR type LIKE '%SPECIAL%' ) )";

#print $qrystr . "\n";

##
## Set up the table and make the query
##
$dbh = DBI->connect(qq[DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');
$loc_dbh = DBI->connect(qq[DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');
$sth = $dbh->prepare($qrystr)
    or die "prepare: " . $dbh->errstr();
$sth->execute();
$sth->bind_columns(\$startday,\$endday,\$type,\$loc,\$leader,\$band,\$comments,
                   \$name,\$stdloc,\$dburl,\$dbtime)
    or die "bind_columns: " . $dbh->errstr();
##
## Print out results
##
#print "content-type: text/html\n\n";
while ($sth->fetch) {
	# Adjust dates and comments
	($st_yr, $st_mon, $st_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
	$st_day =~ s/^0//g if $st_day < 10;
	$st_mon =~ s/^0//g if $st_mon < 10;
	$comments =~ s/<q>/"/g;
	if ($endday ne "") {
		($end_yr, $end_mon, $end_day) =
		    ($endday =~ /(\d+)-(\d+)-(\d+)/);
		$end_day =~ s/^0//g if $end_day < 10;
		$end_mon =~ s/^0//g if $end_mon < 10;
	}
	print "<p class=\"listing\">\n";
	print $day_lst{&day($st_mon,$st_day,$st_yr)}.", ".
              $mon_lst[$st_mon-1] . " " . $st_day;
	if ($endday ne "") {
		print "-";
	       
			print $day_lst{&day($end_mon, $end_day, $end_yr)}.
		        ", ".$mon_lst[$end_mon-1] . " " . $end_day . ', ' . $end_yr;
	       
	}
        else {
	       print ", " . $st_yr;
        }
	print ":  ";
	# get location information
	$loc_qry = "SELECT * FROM venue";
	$loc_qry .= " WHERE vkey = '" . $loc . "'";
	$loc_sth = $loc_dbh->prepare($loc_qry);
	$loc_sth->execute();
	while (($key, $hall, $addr, $city, $ven_comment) =
	    $loc_sth->fetchrow_array()) {
		$loc_hall = $hall;
		$loc_addr = $addr;
		$loc_city = $city;
		$loc_ven_comment = $ven_comment;
	}
print "\n<!-- band=\"" . $band . "\" -->\n";
	if ($type =~ /CAMP/) {
		print "<strong>$type</strong>: ";
		#print $loc_hall . ", " . $loc_ven_comment . ".  ";
		print $loc_hall;
		if ($loc_ven_comment ne "") { print ", " . $loc_ven_comment; }
		print ".  ";
	        print "<em>$comments</em>.\n";
		if ($leader !~ /^$/) {
		    print $leader;
		    print " with music by ", $band if ($band !~ /^$/);
		} else {
                    print "Music by ", $band if ($band !~ /^$/);
		}
	} else {
		print "<strong>$type</strong>";
		print " at " . $loc_hall . " in " . $loc_city . ".  ";
	        if ($comments !~ /^$/) { print "<em>$comments</em>" . ".\n";}
print "\n<!-- band=\"" . $band . "\" -->\n";
		if ($leader !~ /^$/) {
		    print $leader;
		    print " with music by ", $band if ($band !~ /^$/);
		} else {
                    print "Music by ", $band if ($band !~ /^$/);
		}
	}
        if (defined($dburl) && $dburl =~ /[A-Za-z]/) {
	   print ' <a href="'.$dburl.'">More Info</a>'."\n";
	}
	print "</p>\n";
}
$sth->finish();
