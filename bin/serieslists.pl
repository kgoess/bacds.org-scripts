#!/usr/bin/perl -w
##
## Print out dances for each series.
##
use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year Day_of_Week_to_Text);
use DBI;

my ($class);
my ($dbh, $sth);
my ($startday, $endday, $type, $loc, $leader, $band, $comments);
my ($today_year, $today_mon, $today_day, $today, $today_sec);
my ($date_yr, $date_mon, $date_day, $date, $date_sec);
my ($qrystr);
my ($style, $styles, $venue, $day, $day2, $day3, $day4, $day5, $day6, $day7);
my ($venues);
my (@vlist, @slist, @dlist);
my ($wday);
my (@vals);
my ($varname, $data);
my ($i);
my %day_map = (
	"Mon" => 1,
	"Tue" => 2,
	"Wed" => 3,
	"Thu" => 4,
	"Fri" => 5,
	"Sat" => 6,
	"Sun" => 7,
);
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

my ($trailer, $p2, $p3, $p4);

# parse arguments
@vals = split(/&/,$ENV{'QUERY_STRING'});
#@vals = split(/&/,$ARGV[0]);
foreach $i (@vals) {
	($varname, $data) = split(/=/,$i);
	$style = $data if $varname eq "style";
        $styles = $data if $varname eq "styles";
	$venue = $data if $varname eq "venue";
	$venues = $data if $varname eq "venues";
	$day = $data if $varname eq "day";
	$day2 = $data if $varname eq "day2";
        $day3 = $data if $varname eq "day3";
	$day4 = $data if $varname eq "day4";
	$day5 = $data if $varname eq "day5";
        $day6 = $data if $varname eq "day6";
	$day7 = $data if $varname eq "day7";
        
}
@vlist = split ',', $venues if $venues;
@slist = split ',', $styles if $styles;
##
## Get the current date.
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
$qrystr .= " WHERE startday >= '" . $today . "'";
if ($style) {
    $qrystr .= " AND type LIKE '%" . $style . "%'";
}
    if (@slist) {
	$qrystr .= " AND ( ";
	my $style;
	$style = shift @slist;
	$qrystr .= " type LIKE '%" . $style . "%'";
	foreach $style (@slist) {
		$qrystr .= " or type LIKE '%" . $style . "%'";
	}
	$qrystr .= " )";
}
if (@vlist) {
	$qrystr .= " AND ( ";
	my $venue;
	$venue = shift @vlist;
	$qrystr .= " loc LIKE '" . $venue . "%'";
	foreach $venue (@vlist) {
		$qrystr .= " or loc LIKE '" . $venue . "%'";
	}
	$qrystr .= " )";
}
if ($venue) {
	$qrystr .= " AND ( loc LIKE '" . $venue . "%' )";
}

##$qrystr .= " AND (loc LIKE '" . $venue . "%'";
##$qrystr .= " or loc LIKE 'FUM' or loc LIKE 'STA'" if$venue eq "PA";
##$qrystr .= ")";

#print "query is $qrystr\n";

##
## Set up the table and make the query
##
$dbh = DBI->connect(qq[DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');
$sth = $dbh->prepare($qrystr);
$sth->execute();

##
## Print out results
##
#print "content-type: text/html\n\n";
while (($startday,$endday,$type,$loc,$leader,$band,$comments,$p2,$p3,$p4) = 
        $sth->fetchrow_array()) {
	($date_yr, $date_mon, $date_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
	$wday = Day_of_Week($date_yr, $date_mon, $date_day);
	$date_day =~ s/^0//g if $date_day < 10;
	$comments =~ s/\<q\>/"/g if $comments;
#print "days are " . $day_map{$day} . " and " . $wday . "\n";
        
 	$trailer = "\n";
        
	if ($day_map{$day} eq $wday  ||
	   $day2 && ($wday && $day_map{$day2} eq $wday)  || 
	   $day3 && ($wday && $day_map{$day3} eq $wday)  || 
	   $day4 && ($wday && $day_map{$day4} eq $wday)  || 
	   $day5 && ($wday && $day_map{$day5} eq $wday)  || 
	   $day6 && ($wday && $day_map{$day6} eq $wday)  || 
           $day7 && ($wday && $day_map{$day7} eq $wday) )   {
          if (($type =~ /SPECIAL/ ) || ( $type =~ /WOODSHED/ ) ||
              ($type =~ /WORKSHOP/ )) {
            my $class = "special";
	    $class = "workshop" if ( $type =~ /WORKSHOP/ );
	    $class = "woodshed" if ( $type =~ /WOODSHED/ );
	    print "<!-- TYPE = $type -->\n";
	    print "<div class=\"$class\">\n";
	    $trailer = '</div><br /><br />'."\n";
	  }
		print "<a name=\"$startday-$type\"></a>\n";
		print "<p class=\"dance\">\n";
		print "<b class=\"date\">";
		print Day_of_Week_to_Text($wday).", ".$mon_lst[$date_mon-1] . " " . $date_day . "</b><br />\n";
		if ($leader) {
		      print "Caller:  " . $leader . "<br />\n";
		}
		$band =~ s/\<q\>/"/g if $band;
		print "Band:  " . $band . "<br /><br />\n" if $band;
		print "</p>\n";
		if ($comments) {
			print "<p class=\"comment\">\n";
			print "$comments\n";
 		       
                       if ( $type =~ /WORKSHOP/ ) {
		    
                      
			   print "<br \>";
			   print "Stay for the dance that follows!\n";
			
			print "</p>\n";
		        }
		}
	}
#print "days are " . $day_map{$day2} . " and " . $wday . "\n" if $day2 ne "";
#	if ($day2 && ($wday && ($day_map{$day2} eq $wday))) {
#		print "<a name=\"$startday-$type\"></a>\n";
#		print "<p class=\"dance\">\n";
#		print "<b class=\"date\">";
#		print $mon_lst[$date_mon-1] . " " . $date_day . "</b><br />\n";#
#		if ($leader) {
#		      print "Caller:  " . $leader . "<br />\n";
#		}
#		print "Band:  " . $band . "<br /><br />\n" if $band;
#		print "</p>\n";
#		if ($comments && $comments ne "") {
#			print "<p class=\"comment\">\n";
#			print "$comments\n";
#			print "</p>\n";
#		}
#	}
	$type = "";
        print $trailer;
}
