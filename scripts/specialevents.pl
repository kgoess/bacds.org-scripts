#!/usr/bin/perl -w
##
## Find out what special events are coming up.
##
## public_html/scripts/make-frontpage-files.sh:perl scripts/specialevents.pl > specialevents.html
##
## This script doesn't take any parameters.
use strict;
use Date::Day qw/day/;

use bacds::Model::Venue;
use bacds::Model::Event;

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
    


##
## Print out results
##
my @events = bacds::Model::Event->load_all(camps_and_specials => 1);
foreach my $event (sort { $b->startday cmp $a->startday } @events) {
    my $startday = $event->startday;
    my $endday   = $event->endday;
    my $type     = $event->type;
    my $loc      = $event->loc;
    my $leader   = $event->leader;
    my $band     = $event->band;
    my $comments = $event->comments;
    my $dburl    = $event->url;
    
	# Adjust dates and comments
	my ($st_yr, $st_mon, $st_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
	$comments =~ s/<q>/"/g;

    my ($end_yr, $end_mon, $end_day);
	if ($endday ne "") {
		($end_yr, $end_mon, $end_day) =
		    ($endday =~ /(\d+)-(\d+)-(\d+)/);
	}
	print "<p class=\"listing\">\n";
	print $day_lst{&day($st_mon,$st_day,$st_yr)}.", ".
              $mon_lst[$st_mon-1] . " " . $st_day;
	if ($endday ne "") {
		print "&ndash;";
	       
			print $day_lst{&day($end_mon, $end_day, $end_yr)}.
		        ", ".$mon_lst[$end_mon-1] . " " . $end_day . ', ' . $end_yr;
	       
	}
        else {
	       print ", " . $st_yr;
        }
	print ":  ";
	# get location information
    my ($loc_hall, $loc_city,$loc_ven_comment);
    if (my $venue = bacds::Model::Venue->load(vkey => $loc)) {
        $loc_hall = $venue->hall;
        $loc_city = $venue->city;
        $loc_ven_comment = $venue->comment;
    }
    print "\n";
	if ($type =~ /CAMP/) {
		print "<strong>$type</strong>: ";
		#print $loc_hall . ", " . $loc_ven_comment . ".  ";
		print $loc_hall;
		if ($loc_ven_comment ne "") { print ", " . $loc_ven_comment; }
		#print ".  ";
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
        print "\n";
		if ($leader !~ /^$/) {
		    print $leader;
		    print " with music by ", $band if ($band !~ /^$/);
		} else {
                    print "Music by ", $band if ($band !~ /^$/);
		}
	}
        if (defined($dburl) && $dburl =~ /[A-Za-z]/  && $dburl ne 'SUPPRESS') {
	   print ' <a href="'.$dburl.'">More Info</a>'."\n";
	}
	print "</p>\n";
}

1;

