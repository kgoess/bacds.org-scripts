#!/usr/bin/perl -w
##
## Find out what dances are happening in the next week.
##
## This file is being tracked in git. Do a 'git clone /var/lib/git/bacds.org-scripts/'
## to check out the repository, do your edits there, and copy the file into place
## at /var/www/bacds.org/public_html/scripts/dancefinder.pl, or type "make install".
#
use strict;
use Time::Local;
use Date::Format;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year);
use Date::Day;
use DBI;
use CGI;

my ($dbh, $loc_dbh, $sth, $loc_sth);
my ($startday,$endday,$type,$loc,$leader,$band,$comments);
my ($st_day, $st_mon, $st_yr, $end_day, $end_mon, $end_yr);
my ($today_year,$today_mon,$today_day,$today, $today_sec);
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($s_day, $s_mon, $s_year, $e_day, $e_mon, $e_year);
my ($qrystr, $cqrystr, $qrydif, $loc_qry, $loc_type);
my ($style, $venue, $numdays);
my ($json, $jsonobject, $sdate, $edate, $start, $end, $id);
my ($styleurl, $danceurl, $dburl, $stdloc, $header, $trailer);
my ($outputtype, $muso, $qmuso, $caller, $qcaller);
my @vals;
my ($i, $varname, $data, $debugmsg);
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
my %day_lst = ('MON' => 'Monday',
                   'TUE' => 'Tuesday',
                   'WED' => 'Wednesday',
                   'THU' => 'Thursday',
                   'FRI' => 'Friday',
                   'SAT' => 'Saturday',
                   'SUN' => 'Sunday' );

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

#sub get_event_url($$$);
#sub get_hall_name_city($);

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
##      json - if given, we want json output
##      jsonobject - if given we want the jsonoutput wrapped in an object named with the value of jsonobject
##      sdate - if given, we start with sdate (yyyy-nn-dd) rather than today
##      edate - if given, we use edate rather than sdate+numdays
##      start - unix time stamp which we'll translate to sdate (support json feed for fullcalendar.js)
##      end  - unix time stamp which we'll translte edate (as above)
##

$numdays = $style = $venue = $outputtype = $muso = $caller= $json = $jsonobject = $edate = $sdate = $start = 
$end = '';

if ( $ENV{"REQUEST_METHOD"} eq "BOGUS-WAS-GET"  or  
     $ENV{'REQUEST_METHOD'} eq "") {

@vals = split(/&/,$ENV{"QUERY_STRING"}) if $ENV{"QUERY_STRING"};
foreach $i (@vals) {
            ($varname, $data) = split(/=/,$i);
            $style = $data if $varname eq "style";
            $venue = $data if $varname eq "venue";
            $numdays = $data if $varname eq "numdays";
            $outputtype = $data if $varname eq "outputtype";
	    $muso = $data if $varname eq "muso";
	    $caller = $data if  $varname eq "caller";
            $json = $data if $varname eq "json";
            $jsonobject = $data if $varname eq "jsonobject";
            $sdate = $data if $varname eq "sdate";
            $edate = $data if $varname eq "edate";
            $start = $data if $varname eq "start";
            $end = $data if $varname eq "end";
print STDERR "dancefinder.pl:  varname=", $varname, " value=", $data, "\n";
$debugmsg = "GET method, $style, $venue, $numdays, $outputtype, $muso, $caller";
}

}


if ( $ENV{"REQUEST_METHOD"} eq "POST" || $ENV{"REQUEST_METHOD"} eq "GET" ) {
#
# request method not get, should be POST
#
    
my %params;
%params = $q->Vars;
$q->delete_all();    

        $numdays = $params{'numdays'} if defined($params{'numdays'});
        $style = $params{'style'} if defined($params{'style'});
        $venue = $params{'venue'} if defined($params{'venue'});
	$outputtype = $params{'outputtype'} if defined($params{'outputtype'});
        $muso = $params{'muso'} if defined($params{'muso'});
	$caller = $params{'caller'} if defined($params{'caller'});

        # apw 20140524  wedge in json output and start and end dates based on caller input
        $json = $params{'json'} if defined($params{'json'});
        $jsonobject = $params{'jsonobject'} if defined($params{'jsonobject'});
        if ($jsonobject ne  "") {$json="TRUE";}
        $sdate = $params{'sdate'} if defined ($params{'sdate'});
        $edate = $params{'edate'} if defined ($params{'edate'});
        $start = $params{'start'} if defined ($params{'start'});
        $end = $params{'end'} if defined ($params{'end'});
    $debugmsg = "POST method, $numdays, $style, $venue, $outputtype, $muso, $caller";
    
}    

##
## Futzing with JSON; if start or end are defined we stick them into $sdate / $edate respectively.
##

if ($start ne ""){$sdate = time2str("%Y-%m-%d", $start)};
if ($end ne ""){$edate = time2str("%Y-%m4%d", $end)};


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

if ($sdate eq "") {$sdate = $today};
$s_year = substr($sdate, 0, 4);
$s_mon = substr($sdate,5,2);
$s_day = substr($sdate,8,2);


if ($numdays ne ""  && $numdays > 1) {
	##
	## Now figure out what the date will be in $numdays.
	##
	$last_sec = $today_sec + (86400 * ($numdays));
	($last_day, $last_mon, $last_year) = (localtime($last_sec))[3,4,5];
	$last_mon++;
	$last_mon = "0$last_mon" if $last_mon < 10;
	$last_day = "0$last_day" if $last_day < 10;
	$last_year += 1900;
	$last = "$last_year-$last_mon-$last_day";

#print "Today is $today\n";
#print "It will be $last in $numdays days\n";

}

if ($edate ne "") {
 $last = $edate;
 $last_year = substr ($edate, 0, 4);
 $last_mon = substr ($edate, 5, 2);
 $last_day = substr ($edate, 8, 2);
}


my ($query_year);
$query_year = "";
if ($s_year != $today_year) {$query_year = $s_year};

##
## Now build our query string
##
$qrystr = 
   "SELECT startday,endday,type,loc,leader,band,comments,url FROM schedule$query_year";
$cqrystr = "SELECT COUNT(*) FROM schedule$query_year";
#
if (($numdays == 0) && ($edate eq "")) {
    $qrydif .= " WHERE startday >= '" . $sdate . "'";
} else {    
    

if ($numdays == 1) {
        

$qrydif .= " WHERE startday = '" . $sdate . "'";
    } else {
        $qrydif .= " WHERE startday >= '" . $sdate . "'";
        $qrydif .= " AND startday < '" . $last . "'";
    }
}    

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
#$qrydif .= " AND endday IS NULL";
#$qrydif .= " AND leader IS NOT NULL";

$qrystr .= $qrydif if defined($qrydif);
$cqrystr .= $qrydif if defined($qrydif);

print STDERR "DANCEFINDER.PL QUERY: ", $qrystr, "\n";

##
## Set up the table and make the query
##
$dbh = DBI->connect("DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\",'','');
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
## if it's !inline then we want a header
#
if ($outputtype  !~ /inline/i) {
if ($json eq "TRUE") {
       #print "content-type: application/json\n\n";
} else {											   
        print $q->header;
	print <<ENDHTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xthml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<title>Results from dancefinder query</title>
ENDHTML
	open(METAFILE,"<$meta_file") || die "can't open $meta_file: $!";
	print while <METAFILE>;
	close(METAFILE);
	print <<ENDHTML;
<link rel="stylesheet" title="base" type="text/css" href="/css/base.css" />
</head>
<body id="scriptoutput">
<table>
<tr>
<td class="main">
<h1>
ENDHTML
        $loc_hall = $loc_city = ' ';
	print ucfirst(lc($style)) . " " if $style;
	print "Dances";
	if ($venue) {
		($loc_hall, $loc_city) = get_hall_name_city($venue);
		print " At " . $loc_hall . " in " . $loc_city;
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
##        print "$debugmsg\n";
}
}

## print "numdays = $numdays, query = $qrystr";

    if ($json eq "TRUE") {
	$id = 0;
	print "$jsonobject [ ";
}    

if ($numrows) {

    
while (($startday,$endday,$type,$loc,$leader,$band,$comments,$dburl)= 
        $sth->fetchrow_array()) {
               $styleurl = '';	         
		# Get style URL
	        #$styleurl = "http://www.bacds.org/series/community/" 
	        #    if ! $styleurl && $loc eq "FSJ"; 
		$styleurl = "http://www.bacds.org/series/english/"
		    if ! $styleurl && $type =~ /^ENGLISH/;
		$styleurl = "http://www.bacds.org/series/english/"
		    if ! $styleurl && $type =~ /ENGLISHWORKSHOP/;
	        $styleurl = "http://www.bacds.org/series/english/"
	            if ! $styleurl && $type =~ /ECDWORKSHOP/;
		$styleurl = "http://www.bacds.org/series/contra/"
		    if ! $styleurl && $type =~ /CONTRA/;	
          	$styleurl = "http://www.bacds.org/series/contra/"
		    if ! $styleurl && $type =~ /WORKSHOP/;
		$styleurl = "http://www.bacds.org/series/ceilidh/"
		    if ! $styleurl && $type =~ /CEILIDH/;
		$styleurl = "http://www.bacds.org/series/woodshed/"
		    if ! $styleurl && $type =~ /WOODSHED/;
	
# If there's a $danceurl defined already for this special event, leave it
# alone - it's a special case of a regular series (holiday party, etc).  If
# not, point to events.
	    
		# Get dance URL
		my $turl;
	       
		$danceurl = $styleurl;
		if ($type) {
		    $turl = get_event_url($startday,$type,$loc);
		    $danceurl .= $turl if ($styleurl && $turl);		  
		}
	        if (!$turl && 
	            ($type =~ /SPECIAL/ || $type =~ /CAMP/)) {
		    $styleurl = "http://www.bacds.org/events/";
		    $danceurl = "http://www.bacds.org/events/";
		}

#print STDERR $danceurl, "\n";

		# Adjust date
		($st_yr,$st_mon,$st_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
		$st_day =~ s/^0//g if $st_day < 10;
		$st_mon =~ s/^0//g if $st_mon < 10;

		# Get location information
		$loc_dbh = DBI->connect("DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\",'','');
		$loc_qry = "SELECT * FROM venue";
		$loc_qry .= " WHERE vkey = '" . $loc . "'";
		$loc_sth = $loc_dbh->prepare($loc_qry);
		$loc_sth->execute();
	        $loc_hall = $loc_addr = $loc_city = $loc_ven_comment = ' ';
		while (($key, $hall, $addr, $city, $ven_comment) = $loc_sth->fetchrow_array()) {
			$loc_hall = $hall;
			$loc_addr = $addr;
			$loc_city = $city;
			$loc_ven_comment = $ven_comment;
		}
	        # If a URL was specified in the db, override all other URLS.
	        if (defined($dburl) && $dburl !~ /^$/) {
		          $styleurl = $dburl;
                          $danceurl = $dburl;
		}
		# And print the thing
	    
	if ($json eq "TRUE") {
	    if ($id > 0) {print ',';}
	    $id++;
	    my $titlestring = "$type at $loc_hall in $loc_city.";
	    my ($bordercolor, $bgcolor, $textcolor);
	    $bordercolor = $bgcolor = $textcolor = '';
	    
	    if ($leader !~ /^$/) {$titlestring.="  Led by $leader."; }
	    if ($band !~ /^$/) {$titlestring.= "  Music by $band.";}
	    if (defined($comments) && $comments !~ /^$/) {
		                                        $comments =~ s/<q>/\"/g;
		                                 
                    $titlestring.="  - $comments"
                                            if defined($type) && ($type =~ /SPECIAL/ ||
	            		                                                $type =~ /WORKSHOP/ ||
			                                                $type =~ /CAMP/);
                  
            }
  
	    #$titlestring =~ s/\'/\\'/g;
            $titlestring =~ s/\"//g;
	    $titlestring =~ s/<[^>]*>//g;
	    $titlestring =~ s/&ndash;/-/g;
            $titlestring =~ s/&mdash;/-/g;
            $titlestring =~ s/&Eacute;/E/g;
            $titlestring =~ s/&eacute;/e/g;
            $titlestring =~ s/&amp;/&/g;

            if ($type =~ /SPECIAL/  || $type =~/CAMP/ || $type =~ /WORKSHOP/) {
		$bgcolor = 'plum';
		$bordercolor = 'dimgrey';
		$textcolor = 'black';							
						       
	    } elsif ($type =~ /ENGLISH/) {
		$bgcolor = 'darkturquoise';
		$bordercolor = 'darkblue';			      
		$textcolor = 'black';			      
					      
            } elsif ($type =~ /CONTRA/) {
		$bgcolor = 'coral';
		$bordercolor = 'bisque';
		$textcolor = 'black';
	    } elsif ($type =~ /WOODSHED/) {
              $bgcolor = 'burlywood';
	      $bordercolor = 'sienna';
	      $textcolor = 'black';
	    } else {
		
		$bgcolor = 'yellow';
		$bordercolor = 'antiquewhite';
		$textcolor = 'black';
	    }
					    
 print <<ENDJSON;
	    { \"id\" : \"$id\",
	      \"url\" : \"$danceurl\",
	      \"start\" : \"$startday\",
	      \"end\" : \"$endday\",
	      \"title\" : \"$titlestring\",
	      \"allDay\" : true,
	      \"backgroundColor\" : \"$bgcolor\",
              \"borderColor\" : \"$bordercolor\",
              \"textColor\" : \"$textcolor\"
	    }
ENDJSON
  
	} else {
	if (defined($type) && ($type =~ /SPECIAL/ || 
                              $type =~ /WORKSHOP/ ||
                              $type =~ /WOODSHED/ ||
                              $type =~ /CAMP/) ){
           my $class = "special";
           $class = "workshop" if ( $type =~ /WORKSHOP/ );
           $class = "woodshed" if ( $type =~ /WOODSHED/ );
           $class = "camp" if ( $type =~ /CAMP/ );
				  
	    $header = qq(<br /><div class="$class">\n);
	    $trailer = qq(</div>\n);
        } else {
	    $header = "\n";
	    $trailer= "\n";
	}

	if ($endday ne "") {
		($end_yr, $end_mon, $end_day) =
		    ($endday =~ /(\d+)-(\d+)-(\d+)/);
		$end_day =~ s/^0//g if $end_day < 10;
		$end_mon =~ s/^0//g if $end_mon < 10;
	}
	print $header;
	print "<p class=\"listing\">\n";
	print $day_lst{&day($st_mon,$st_day,$st_yr)}.", ".
              $monlst[$st_mon-1] . " " . $st_day;
	if ($endday ne "") {
		print "-";
	       
			print $day_lst{&day($end_mon, $end_day, $end_yr)}.
		        ", ".$monlst[$end_mon-1] . " " . $end_day . ', ' . $end_yr;
	       
	}
        else {
	       print ", " . $st_yr;
        }

		my $schemeless_danceurl = $danceurl ? $danceurl =~ s/^https?://r : '';
		print ": <strong>$type</strong> ";
		print " at ";
		print "<a href=\"" .$schemeless_danceurl . "\">" if $danceurl;
		print $loc_hall;
		print " in " . $loc_city;
		print "</a>" if $danceurl;
		print ".  ";
		$band =~ s/\<q\>/"/g if ($band !~ /^$/);
		if ($leader !~ /^$/) {
		    print $leader;
		    print " with ", $band, "\n" if ($band !~ /^$/);
		} else {
		    print "Music by ", $band, "\n" if ($band !~ /^$/);
		}
                # if it's a special event, print out the title.
		if (defined($comments) && $comments !~ /^$/) {
		    $comments =~ s/<q>/"/g;
                    print ' <em>', $comments, '</em>.', "\n"
		      if defined($type) && ($type =~ /SPECIAL/ || 
                                            $type =~ /WORKSHOP/ ||
                                            $type =~ /CAMP/);
		}
                print '&nbsp;<a href="'.$schemeless_danceurl.'">More Info</a>'."\n";
										       
		print "</p>\n";
                print $trailer;

   }
	}
} else {
    
   if ($json ne "TRUE" && (!$outputtype || ($outputtype && ($outputtype !~ /inline/i)))) { 
	print "<p class=\"listing\">\n";
	print "There are no upcoming dances that meet your criteria.\n";
	print "</p>\n";
       }
}

if ($json eq "TRUE") {
    print "]\n";
} else {
if (!$outputtype || ($outputtype && ($outputtype !~ /inline/i))) {
print <<ENDHTML;
</td>
</tr>
</table>
</body>
</html>
ENDHTML
}
}
    
#sub get_event_url ($$$) {
sub get_event_url {
	my ($date, $type, $loc) = @_;
	my @day_list = ("sun","mon","tue","wed","thu","fri","sat");
	my ($yr, $mon, $day);
	my ($wday);
	my ($wdayname);
	my $eventurl = undef;

	## The following data structure maps venues that host only one

	## event to the sub-URL that they correspond to

	my %url_map = (
		'SJP' => 'san_francisco/',
                'BET' => 'san_francisco/',
		'SF' => 'san_francisco/',
	        'SBE' => 'palo_alto/',
		'MT' => 'palo_alto/',
	        'MVM'=> 'palo_alto/',
		'PA' => 'palo_alto/',
		'FUM' => 'palo_alto/',
		'STA' => 'palo_alto/',
		'ECV' => 'el_cerrito/',
		'FLX' => 'mountain_view/',
	        'TDBPE' => 'peninsula/',
	        'AST' => 'peninsula/',
	        'ASE' => 'peninsula/',
		'CRO' => 'berkeley_wed/',
	        'SPC' => 'san_francisco/',
	        'HPP' => 'atherton/',
                'HVC' => 'hayward'
	);

	## And pick the low-hanging fruit.
	if ($url_map{$loc}) {
		$eventurl = $url_map{$loc};
	}

	## If $eventurl is not defined at this point, sort out what it is.
	if (!defined($eventurl)) {
    
            if ($loc eq "FBC") {
                    $eventurl = "peninsula" if $type =~ /ENGLISH/;
                    $eventurl = "palo_alto" if $type =~ /CONTRA/;
                } 

	        if ($loc eq "HUM"  || $loc eq "OV2") {
		    $eventurl = "east_bay_fri" if $type =~ /CONTRA/;
		    $eventurl = "oakland" if $type =~ /CEILIDH/;
	        }
	    
	        if ($loc eq "FSJ"  || $loc eq "COY") {
		    $eventurl = "san_jose" if $type =~ /CONTRA/;
		    $eventurl = "san_jose" if $type =~ /ENGLISH/;
		}

                if ($loc eq "SME") {
                               ## Get the day of week
                                ($yr, $mon, $day) =
                                    ($date =~ /(\d+)-(\d+)-(\d+)/);
                                $wday = Day_of_Week($yr, $mon, $day);
                                if ($wday == 5) {
                                    $eventurl = "palo_alto_reg";

                                } else {
                                $eventurl = "peninsula"; 
                                }
                }

		# Grace North Church/Christ Church Berkeley should be the only location at this point.
		if ($loc eq "GNC" || $loc eq "STALB" || $loc eq "STC"|| $loc eq "CCB" || $loc eq "FUO"  || $loc eq "FBH"  || $loc eq "CRO" ) {
			# Only one CONTRA series uses the hall
		        $eventurl = "berkeley_wed" if $type =~ /CONTRA/;
		        # and there's also a WORKSHOP series, same night
		        $eventurl = "berkeley_wed" if $type =~ /CONTRAWORKSHOP/;
		        $eventurl = "berkeley_wed_workshop" if 
		           $type =~ /^ENGLISHWORKSHOP$/;
		        $eventurl = "berkeley_wed" if 
		           $type =~ /ECDWORKSHOP/;

			# If type is ENGLISH, we need to know the day of the
			# week
			if ($type =~ /ENGLISH$/) {
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

#sub get_hall_name_city ($) {
sub get_hall_name_city {
	my ($venue) = @_;
	my ($dbh, $qry, $sth);
	my ($hall, $city);
	my ($loc_hall, $loc_city);
        $hall = ' ';
        $city = ' ';

	# Get location information
	$dbh = DBI->connect("DBI:CSV:f_dir=/var/www/bacds.org/public_html/data;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\",'','');
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

