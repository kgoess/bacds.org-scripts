#!/usr/bin/env perl -w
##
## Find out what dances are happening in the next week.
##
## This file is being tracked in git. Do a 'git clone /var/lib/git/bacds.org-scripts/'
## to check out the repository, do your edits there, and copy the file into place
## at /var/www/bacds.org/public_html/scripts/dancefinder.pl, or type "make install".
#
## This file is formatted with spaces. Please do not insert any hard tab characters.
#
## The dancefinder.pl script is used to create the 10day.html and 18day.html
## include files.
## It's called from make-frontpage-files.sh once per minute by cron.
##
## It's also used by the interactive calendar at
## https://bacds.org/livecalendar.html which runs https://fullcalendar.io/ and
## sends json requests to dancefinder.pl
#
use strict;
use Time::Local qw/timelocal/;
use Date::Format qw/time2str strftime/;
use Date::Calc qw/Day_of_Week/;
use Date::Day qw/day/;
use CGI;

use bacds::Model::Venue;
use bacds::Model::Event;

our $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
our $TEST_TODAY = $ENV{TEST_TODAY};

my ($st_day, $st_mon, $st_yr, $end_day, $end_mon, $end_yr);
my ($last_year,$last_mon,$last_day,$last, $last_sec);
my ($style, $venue, $numdays);
my ($json, $jsonobject, $sdate, $edate, $start, $end, $id);
my ($styleurl, $danceurl, $dburl, $stdloc, $header, $trailer);
my ($outputtype, $muso, $qmuso, $caller, $qcaller);
my ($debugmsg);
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
my %day_lst = (
    'MON' => 'Monday',
    'TUE' => 'Tuesday',
    'WED' => 'Wednesday',
    'THU' => 'Thursday',
    'FRI' => 'Friday',
    'SAT' => 'Saturday',
    'SUN' => 'Sunday'
);

my ($loc_hall, $loc_city, $loc_ven_comment);
my $meta_file = $ENV{META_FILE} || '/var/www/bacds.org/public_html/shared/meta-tags.html';
my $numrows;
my $q = new CGI;


##
## Grab arguments
##
## Arguments/variables are:
##
##    style -- dance style
##    venue -- dance venue
##    numdays -- number of days we should report for
##    outputtype -- type of output
##    caller -- caller at dance
##    muso -- musical staff
##    json - if given, we want json output
##    jsonobject - if given we want the jsonoutput wrapped in an object named
##                 with the value of jsonobject
##    sdate - if given, we start with sdate (yyyy-nn-dd) rather than today
##    edate - if given, we use edate rather than sdate+numdays
##    start - unix time stamp which we'll translate to sdate (support json feed
##            for fullcalendar.js)
##     end  - unix time stamp which we'll translte edate (as above)
##

$numdays = $style = $venue = $outputtype = $muso = $caller = $json
     = $jsonobject = $edate = $sdate = $start = $end
     = '';

if ( $ENV{"REQUEST_METHOD"} eq "BOGUS-WAS-GET"  or
     $ENV{'REQUEST_METHOD'} eq "") {

    my @vals = split(/&/,$ENV{"QUERY_STRING"}) if $ENV{"QUERY_STRING"};
    foreach my $i (@vals) {
        my ($varname, $data) = split(/=/,$i);
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
    if ($jsonobject ne  "") {
        $json="TRUE";
    }
    $sdate = $params{'sdate'} if defined ($params{'sdate'});
    $edate = $params{'edate'} if defined ($params{'edate'});
    $start = $params{'start'} if defined ($params{'start'});
    $end = $params{'end'} if defined ($params{'end'});
    $debugmsg = "POST method, $numdays, $style, $venue, $outputtype, $muso, $caller";

}

##
## Futzing with JSON; if start or end are defined we stick them into $sdate / $edate respectively.
##

if ($start ne ""){
    $sdate = time2str("%Y-%m-%d", $start)
};
if ($end ne ""){
    $edate = time2str("%Y-%m-%d", $end)
};


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

if ($sdate eq "") {$sdate = $today};
my $s_year = substr($sdate, 0, 4);


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

if ($edate ne "") {
    $last = $edate;
    $last_year = substr ($edate, 0, 4);
    $last_mon = substr ($edate, 5, 2);
    $last_day = substr ($edate, 8, 2);
}


### leaving query_year unimplemented until we migrate all the schedule stuff to
### a single table --kg 2022-02-08
my ($query_year);
$query_year = "";
if ($s_year != $today_year) {
    $query_year = $s_year
};

##
## Now build our query
##
my @load_args;
$numdays ||= 0;
if (($numdays == 0) && ($edate eq "")) {
    push @load_args, after => $sdate;
} else {
    if ($numdays == 1) {
        push @load_args, on_date => $sdate;
    } else {
        push @load_args, after => $sdate;
        push @load_args, before => $last;
    }
}

push @load_args, venue => $venue if $venue;;
push @load_args, style => $style if $style;

if ($caller) {
    $qcaller = $caller =~ s/'.+//gr;
    push @load_args, leader => $qcaller;
}

if ($muso) {
    $qmuso = $muso =~ s/'.+//gr;
    push @load_args, band => $muso;
}

print STDERR "DANCEFINDER.PL QUERY: @load_args\n";


#
# load the results
#
my @events = sort { $a->startday cmp $b->startday }
             bacds::Model::Event->load_all(@load_args);

#
# print the results
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
    }
}

if ($json eq "TRUE") {
    $id = 0;
    print "$jsonobject [ ";
}

#if ($numrows) {
if (@events) {

#    while (($startday, $endday, $type, $loc, $leader, $band, $comments, $dburl)
#        = $sth->fetchrow_array()
#    ) {
    foreach my $event (@events) {
        my $startday = $event->startday;
        my $endday   = $event->endday;
        my $type     = $event->type;
        my $loc      = $event->loc;
        my $leader   = $event->leader;
        my $band     = $event->band;
        my $comments = $event->comments;
        my $dburl    = $event->url;

        $styleurl = '';
        # Get style URL
            #$styleurl = "https://www.bacds.org/series/community/"
            #    if ! $styleurl && $loc eq "FSJ";
        $styleurl = "https://www.bacds.org/series/english/"
            if ! $styleurl && $type =~ /^ENGLISH/;
        $styleurl = "https://www.bacds.org/series/english/"
            if ! $styleurl && $type =~ /ENGLISHWORKSHOP/;
            $styleurl = "https://www.bacds.org/series/english/"
                if ! $styleurl && $type =~ /ECDWORKSHOP/;
        $styleurl = "https://www.bacds.org/series/contra/"
            if ! $styleurl && $type =~ /CONTRA/;
              $styleurl = "https://www.bacds.org/series/contra/"
            if ! $styleurl && $type =~ /WORKSHOP/;
        $styleurl = "https://www.bacds.org/series/ceilidh/"
            if ! $styleurl && $type =~ /CEILIDH/;
        $styleurl = "https://www.bacds.org/series/woodshed/"
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
            ($type =~ /SPECIAL/ || $type =~ /CAMP/)
        ) {
            $styleurl = "https://www.bacds.org/events/";
            $danceurl = "https://www.bacds.org/events/";
        }


        # Adjust date
        ($st_yr,$st_mon,$st_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
        $st_day =~ s/^0//g if $st_day < 10;
        $st_mon =~ s/^0//g if $st_mon < 10;

        # Get location information
        if (my $venue = bacds::Model::Venue->load(vkey => $loc)) {
            $loc_hall = $venue->hall;
            $loc_city = $venue->city;
            $loc_ven_comment = $venue->comment;
        }

            # If a URL was specified in the db, override all other URLS.
        if ($dburl) {
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
                    if defined($type)
                       && ($type =~ /SPECIAL/ ||
                           $type =~ /WORKSHOP/ ||
                           $type =~ /CAMP/
                      );

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
                $class = "camp"     if ( $type =~ /CAMP/ );

                $header = qq(<!--br /--><div class="$class">\n);
                $trailer = qq(</div>\n);
            } else {
                $header = "\n";
                $trailer= "\n";
            }

            if ($endday ne "") {
                ($end_yr, $end_mon, $end_day) = ($endday =~ /(\d+)-(\d+)-(\d+)/);
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

            } else {
                print ", " . $st_yr;
            }

            print ": <strong>$type</strong> ";
            print " at ";
            print "<a href=\"" .$danceurl . "\">" if $danceurl;
            print $loc_hall;
            print " in " . $loc_city;
            print "</a>" if $danceurl;
            print ".  ";
            $band =~ s/\<q\>/"/g if ($band !~ /^ *$/);
            if ($leader !~ /^\s*$/) {
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
            print '&nbsp;<a href="'.$danceurl.'">More Info</a>';

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

        if ($loc eq "SME" || $loc eq "STM") {
            ## Get the day of week
            ($yr, $mon, $day) = ($date =~ /(\d+)-(\d+)-(\d+)/);
             $wday = Day_of_Week($yr, $mon, $day);
             if ($wday == 5  && int($day) > 7 && int($day) < 15) {
                 $eventurl = "palo_alto_reg";
             } elsif ($wday == 5 && int($day) < 8) {
                 $eventurl = "palo_alto";
             }
               elsif ($wday == 1) {
                 $eventurl = "atherton";
             } else {
                 $eventurl = "peninsula";
             }
        }

        # Grace North Church/Christ Church Berkeley should be the only location at this point.
        if ($loc eq "GNC"   ||
            $loc eq "STALB" ||
            $loc eq "STC"   ||
            $loc eq "CCB"   ||
            $loc eq "FUO"   ||
            $loc eq "FBH"   ||
            $loc eq "CRO"
        ) {
            # Only one CONTRA series uses the hall
            $eventurl = "berkeley_wed"          if $type =~ /CONTRA/;
            # and there's also a WORKSHOP series, same night
            $eventurl = "berkeley_wed"          if $type =~ /CONTRAWORKSHOP/;
            $eventurl = "berkeley_wed_workshop" if $type =~ /^ENGLISHWORKSHOP$/;
            $eventurl = "berkeley_wed"          if $type =~ /ECDWORKSHOP/;

            # If type is ENGLISH, we need to know the day of the week
            if ($type =~ /ENGLISH$/) {
                ## Get the day of week
                ($yr, $mon, $day) = ($date =~ /(\d+)-(\d+)-(\d+)/);
                $wday = Day_of_Week($yr, $mon, $day);
                $eventurl = "berkeley_wed/"
                    if ($wday == 3 || $wday == 4);
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

    # Get location information
    if (my $venue = bacds::Model::Venue->load(vkey => $venue)) {
        return $venue->hall, $venue->city;
    }
    return;
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

# vim: ts=4 sw=4 et
