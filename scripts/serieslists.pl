#!/usr/bin/perl -w
##
## Print out dances for each series.
##
## Called from the content.html pages for each series like this:
##     <!--#if expr='v("QUERY_STRING") =~ /single-event=([0-9]{4}-[0-9]{2}-[0-9]{2})/ && $1 =~ /(.*)/' -->
##             <!--#include virtual="/scripts/serieslists.pl?single-event=$0&venue=MT" -->
##     <!--#else -->
##             <!--#include virtual="/scripts/serieslists.pl?styles=ENGLISH,ECDWORKSHOP,SPECIAL/ENGLISH&venues=MT,SBE&day=Fri&day2=Thu&day3=Tue" -->
##     <!--#endif -->
##
## In the first case, we're the google events single-event version of the page,
## so we also add the json-ld
##
##
## This file is being tracked in git.  To clone the repo, add yourself to the
## "git" group I created and then do "git clone /var/lib/git/bacds.org-scripts/".
use strict;
use Date::Calc qw(Day_of_Week Day_of_Week_to_Text);
use JSON qw/to_json/;

use bacds::Model::Event;
use bacds::Model::Venue;
use bacds::Utils qw/today_ymd/;

my ($style, $styles, $vkey, $vkeys, @days_to_search, $single_event,
    $start_time, $end_time);

my %day_map = (
    Mon => 1,
    Tue => 2,
    Wed => 3,
    Thu => 4,
    Fri => 5,
    Sat => 6,
    Sun => 7,
);
my @mon_lst = qw(
    January
    February
    March
    April
    May
    June
    July
    August
    September
    October
    November
    December
);

my ($trailer);

# parse arguments
my @vals = split(/&/, $ENV{'QUERY_STRING'});
foreach my $i (@vals) {
    my ($varname, $data) = split(/=/,$i);
    $style = $data if $varname eq "style";
    $styles = $data if $varname eq "styles";
    $vkey = $data if $varname eq "venue";
    $vkeys = $data if $varname eq "venues";
    push @days_to_search, $data if $varname =~ /^day[2-7]?/;
    $single_event = $data if $varname eq "single-event";
    $start_time = $data if $varname eq 'starttime';
    $end_time = $data if $varname eq 'endtime';
}
my @vlist = split ',', $vkeys if $vkeys;
push @vlist, $vkey if $vkey;
my @slist = split ',', $styles if $styles;
push @slist, $style if $style;

#
# load the events for those args
#
my @load_args = 
    $single_event
    ? (
        on_date => $single_event,
        venue_in_list => \@vlist,
    )
    : (
        after => today_ymd(),
        style_in_list => \@slist,
        venue_in_list => \@vlist,
    )
;
my @events = bacds::Model::Event->load_all(@load_args);

##
## Print out results
##
foreach my $event (@events) {
    my $startday = $event->startday;
    my $type     = $event->type;
    my $loc      = $event->loc;
    my $leader   = $event->leader;
    my $band     = $event->band;
    my $comments = $event->comments;
    
    my ($date_yr, $date_mon, $date_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
    my $wday = Day_of_Week($date_yr, $date_mon, $date_day);
    $date_day =~ s/^0//g if $date_day < 10;
    if ($comments) {
        $comments =~ s/\<q\>/"/g;
    } else {
        $comments = "";
    }

    $trailer = "\n";
        
    if ($single_event or 
        grep { $day_map{$_} eq $wday } @days_to_search
    ) {
        if (($type =~ /SPECIAL|WOODSHED|WORKSHOP/ )) {
             my $class = "special";
             $class = "workshop" if ( $type =~ /WORKSHOP/ );
             $class = "woodshed" if ( $type =~ /WOODSHED/ );
             print "<!-- TYPE = $type -->\n";
             print "<div class=\"$class\">\n";
             $trailer = '</div><br /><br />'."\n";
        }
        print "<a name=\"$startday-$type\"></a>\n";
        print "<p class=\"dance\">\n";
        print "<b class=\"date\">\n";
        print qq{<a href="?single-event=$startday">\n};
        print Day_of_Week_to_Text($wday).", ".$mon_lst[$date_mon-1] . " " . $date_day. "\n";
        print qq{</a></b><br />\n};
        my ($venue) = lookup_address_for_vkey($loc);
        if ($venue) {
           print $venue->hall.', '.$venue->address.', '.$venue->city." <br />\n";
        }
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
    print $trailer;
    print generate_jsonld($single_event, $loc, $type, $leader, $band,
                          $comments, $start_time, $end_time) 
        if $single_event;
    $type = "";
}


# see https://schema.org/DanceEvent
# and http://eceilidh.org.uk/cps/structured-data-applied-to-english-ceilidh-events.php
# a useful testing tool: https://search.google.com/structured-data/testing-tool/u/0/
#
# example data from the schedule table:
#     startday|endday|type|loc|leader|band|comments|name|stdloc|url
#     2018-01-02||ENGLISH|ASE|Bruce Hamilton|Anne Bingham Goess, Tom Lindemuth, Bill Jensen
#
# empirical experimentation shows the data is arriving here with " stripped out, so
# it's safe to just dump into the JSON
sub generate_jsonld {
    my ($date, $vkey, $type, $leader, $band, $comments,
        $start_time, $end_time) = @_;

    if (!$start_time) {
        warn "missing start_time for $date $vkey $type\n";
        $start_time = '00:00:00';
    }
    if (!$end_time) {
        warn "missing end_time for $date $vkey $type\n";
        $end_time = '00:00:00';
    }
        

    my $nice_dance_type = ucfirst lc $type;

    # keys to $loc hashref are: vkey|hall|address|city|zip|comment|type
    my $venue = lookup_address_for_vkey($vkey);

    my $offer_url = "https://$ENV{HTTP_HOST}$ENV{DOCUMENT_URI}";

    my $start = join 'T', $date, $start_time;
    my $end   = join 'T', $date, $end_time;


    # new fields eventAttendanceMode: could be Offline, Online or Mixed
    # new field eventStatus could be:
    # 		EventCancelled
    # 		EventMovedOnline
    # 		EventPostponed
    # 		EventRescheduled
    # 		EventScheduled
    # just hard-coding them to start with

    my %json_data = (
       '@context'  => 'http://schema.org',
       '@type'    => ['Event','DanceEvent'],
        name        => "$nice_dance_type Dancing, calling by $leader to the music of $band",
        startDate   => $start,
        endDate     => $end,
        eventAttendanceMode => 'https://schema.org/OfflineEventAttendanceMode',
        eventStatus => 'https://schema.org/EventScheduled',
        organizer => {
           '@context' => 'http://schema.org',
           '@type'    => 'Organization',
            name      => 'Bay Area Country Dance Society',
            url       => 'https://www.bacds.org/'
        },
        location => {
           '@context' => 'http://schema.org',
           '@type'    => 'Place',
            name      => $venue->hall,
            address => {
               '@type'          => "PostalAddress",
                streetAddress   => $venue->address,
                addressLocality => $venue->city,
                postalCode      => $venue->zip,
                addressRegion   => "California",
                addressCountry  => "USA"
            }
        },
        description => "$nice_dance_type Dancing at ".$venue->hall." in ".$venue->city.". ".
            "Everyone welcome, beginners and experts! No partner necessary. ".
            "$comments (Prices may vary for special events or workshops. Check ".
            "the calendar or website for specifics.)",
        image => 'https://www.bacds.org/graphics/bacdsweblogomed.gif',
        performer => [
            {
               '@type' => 'MusicGroup',
                name   => $band,
            },
            {
               '@type' => 'Person',
                name => $leader,
            }
        ],
        offers => [
        {
            '@type' => "Offer",
            name => "supporters",
            price => "20.00",
            priceCurrency => "USD",
            url => $offer_url,
            availability => "http://schema.org/LimitedAvailability",
            validFrom  => $date,
        },{
            '@type' => 'Offer',
            name => 'non-members',
            price => '12.00',
            priceCurrency => 'USD',
            url => $offer_url,
            availability => 'http://schema.org/LimitedAvailability',
            validFrom => $date,
        },{
            '@type' => 'Offer',
            name => 'members',
            price => '10.00',
            priceCurrency => 'USD',
            url => $offer_url,
            availability => 'http://schema.org/LimitedAvailability',
            validFrom => $date,
        },{
            '@type' => 'Offer',
            name => 'students or low-income or pay what you can',
            price => '6.00',
            priceCurrency => 'USD',
            url => $offer_url,
            availability => 'http://schema.org/LimitedAvailability',
            validFrom => $date
        }
        ]

    );

    my $json_str = to_json(\%json_data, { pretty => 1 });
    return <<EOL;
    <script type="application/ld+json">
    $json_str
    </script>
EOL

}

# vkey|hall|address|city|zip|comment|type
# ACC|Arlington Community Church|52 Arlington Avenue|Kensington|||SPECIAL
# ALB|Albany Veteran's Memorial Building|1325 Portland Avenue (off Key RouteBlvd)|Albany|||SPECIAL
sub lookup_address_for_vkey {
    my ($vkey) = @_;

    return bacds::Model::Venue->load(vkey => $vkey);
}

# vim: tabstop=4 shiftwidth=4 expandtab
