#!/usr/bin/perl -w
##
## Find out what ZOOM online events are coming up.
##
## current usage:
## public_html/scripts/make-frontpage-files.sh:perl scripts/zoomevents.pl > zoomevents.html
##
use strict;
use Time::Local;
use DBI;
use Date::Day;

my $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $TEST_TODAY = $ENV{TEST_TODAY};

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments, 
    $name,$stdloc,$dburl,$url,$photo,$performerurl,$pacifictime);
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
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($s_day, $s_mon, $s_year, $e_day, $e_mon, $e_year);
my ($numdays);
my ($key, $hall, $addr, $city, $ven_comment);
my ($loc_year, $loc_hall, $loc_addr, $loc_city, $loc_ven_comment);

$s_year = "";
$loc_year = "";
$loc_hall = "";
$loc_addr = "";
$loc_city = "";
$loc_ven_comment = "";
$comments = "";

##
## First, get the current date.
##
($today_day, $today_mon, $today_year) = my_localtime();
$today_sec = timelocal(0,0,0,$today_day,$today_mon,$today_year);
$today_mon++;
$today_mon = sprintf "%02d", $today_mon;
$today_day = sprintf "%02d", $today_day;
$today_year += 1900;
$today = "$today_year-$today_mon-$today_day";

#print "Today is $today\n";

$numdays = 18;
if ($numdays ne ""  && $numdays > 1) {
	##
	## Now figure out what the date will be in $numdays.
	##
	$last_sec = $today_sec + (86400 * ($numdays));
	($last_day, $last_mon, $last_year) = (localtime($last_sec))[3,4,5];
	$last_mon++;
	$last_mon = sprintf "%02d", $last_mon;
	$last_day = sprintf "%02d", $last_day;
	$last_year += 1900;
	$last = "$last_year-$last_mon-$last_day";

#print "Today is $today\n";
#print "It will be $last in $numdays days\n";

}

my ($query_year);
$query_year = "";
if ($s_year ne $today_year) {$query_year = $s_year};


##
## Now build our query string
##
$qrystr = "SELECT * FROM schedule";
$qrystr .= " WHERE ( ( startday <= '" . $last . "'  ";
$qrystr .= " AND  startday >= '" . $today . "' ) ";
$qrystr .= " AND ( type LIKE '%ZOOM%'  OR type LIKE '%ONLINE%' ) )";

#print $qrystr . "\n";

##
## Set up the table and make the query
##
$dbh = get_dbh();
$loc_dbh = get_dbh();
$sth = $dbh->prepare($qrystr)
    or die "prepare: " . $dbh->errstr();
$sth->execute();
$sth->bind_columns(\$startday,\$endday,\$type,\$loc,\$leader,\$band,\$comments,
                   \$url,\$photo,\$performerurl,\$pacifictime)
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

	# 8May2020 edb rearrange order of field data to be more palatable

	# get location information
	#  8May2020 edb allow multi-word Venue keys, only 1st word counts
	$loc =~ s/ .*$//;

print "\n<!-- type=\"" . $type . "\" -->";
print "\n<!-- leader=\"" . $leader . "\" -->";
print "\n<!-- band=\"" . $band . "\" -->";
print "\n<!-- loc=\"" . $loc . "\" -->";
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
	if ($type =~ /CAMP/) {
		print "<strong>$type</strong>: ";
		#print $loc_hall . ", " . $loc_ven_comment . ".  ";
		print $loc_hall;
	# 8May2020 edb rearrange order of field data to be more palatable
	#	if ($loc_ven_comment ne "") { print ", " . $loc_ven_comment; }
	#	print ";  ";
	#       print "<em>$comments</em>.\n";
		if ($leader =~ /^$/ )
		{
		    print $leader;
		    if (!(($loc =~ /ZOOM/) || ($loc =~ /ONLINE/)
			|| ($loc =~ /FACEBOOK/ )))
		    {
			print " with music by ";
		    }
		    print $band if ($band !~ /^$/);
		} else {
                    print "Music by ", $band if ($band !~ /^$/);
		}
	# 8May2020 edb rearrange order of field data to be more palatable
		if ($loc_ven_comment ne "") { print ", " . $loc_ven_comment; }
		print ";  ";
		print "<em>$comments</em>.\n";
	} else {
		print "<strong>$type</strong>";
		if ($loc_hall =~ /ZOOM/i || $loc_hall =~ /ONLINE/i) {
		   print " at " . $loc_hall . ":  ";
		} else {
		   print " in " . $loc_city . ":  ";
		}
	# 8May2020 edb rearrange order of field data to be more palatable
	#        if ($comments !~ /^$/) { print "<em>$comments</em>" . ".\n";}
print "\n<!-- band=\"" . $band . "\" -->\n";
		if ($leader !~ /^$/) {
		    print $leader;
		}
		if ((($loc =~ /ZOOM/i) || ($loc =~ /ONLINE/i)
		    || ($loc =~ /FACEBOOK/i )) && ($type =~ /workshop/i))
		{
		    # edb 28jul2020 UGLY HACK for workshops & concerts

		    if (!($leader =~ /^$/)) {
			print " leads this " if $type =~ /Workshop/i;
			if ($band eq "") {
			} else {
			    print " " . $band if ($band !~ /^$/);
			}
		    }
		} else {
		    print "<!-- bingo -->\n";
		    print " with music by ", $band if ($band !~ /^$/);
		}
		print " Music by ", $band if ($band !~ /^$/) && $leader eq "";
	# 8May2020 edb rearrange order of field data to be more palatable
	        if ($comments !~ /^$/) { print "<em>$comments</em>" . ".\n";}
	}
        if (defined($dburl) && $dburl =~ /[A-Za-z]/) {
	   print ' <a href=\"'.$dburl.'\">More Info</a>'."\n";
	}
	print "</p>\n";
}
$sth->finish();


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
