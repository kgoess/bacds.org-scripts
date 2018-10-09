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
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year Day_of_Week_to_Text Today);
use DBI;

my ($style, $styles, $venue, $venues, @days_to_search, $single_event);

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
    $venue = $data if $varname eq "venue";
    $venues = $data if $varname eq "venues";
    push @days_to_search, $data if $varname =~ /^day[2-7]?/;
    $single_event = $data if $varname eq "single-event";
}
my @vlist = split ',', $venues if $venues;
push @vlist, $venue if $venue;
my @slist = split ',', $styles if $styles;
push @slist, $style if $style;


##
## Set up the table
##
my $csv_dir = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $dbh = DBI->connect(qq[DBI:CSV:f_dir=$csv_dir;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');

##
## Build the query string
##
my ($query_string, @bind_params) = 
    $single_event
    ? build_single_event_query($single_event, \@vlist)
    : build_upcoming_events_query(\@slist, \@vlist, $dbh); 

##
## Make the query
##
my $sth = $dbh->prepare($query_string) or die $dbh->errstr;
$sth->execute(@bind_params) or die $sth->errstr;

##
## Print out results
##
#print "content-type: text/html\n\n";
while (my ($startday, $endday, $type, $loc, $leader, $band, $comments, $p2, $p3, $p4) = 
        $sth->fetchrow_array()) {
    my ($date_yr, $date_mon, $date_day) = ($startday =~ /(\d+)-(\d+)-(\d+)/);
    my $wday = Day_of_Week($date_yr, $date_mon, $date_day);
    $date_day =~ s/^0//g if $date_day < 10;
    $comments =~ s/\<q\>/"/g if $comments;

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
    print generate_jsonld($dbh, $single_event, $loc, $type, $leader, $band, $comments) 
        if $single_event;
    $type = "";
}

# I'd like to put these into bind params, but gave up after wrestling
# with that for a couple hours
sub build_upcoming_events_query {
    my ($slist, $vlist, $dbh) = @_; 

    my $today = $dbh->quote($ENV{TEST_TODAY} || sprintf "%4.4d-%2.2d-%2.2d", Today());

    my $qrystr = "SELECT * FROM schedule";
    $qrystr .= " WHERE startday >= $today";
    if (@$slist) {
        $qrystr .= " AND ( ";
        my $style = shift @$slist;
        $style = $dbh->quote("%$style%");
        $qrystr .= " type LIKE $style";
        foreach $style (@$slist) {
            $style = $dbh->quote("%$style%");
            $qrystr .= " or type LIKE $style";
        }
        $qrystr .= " )";
    }
    if (@$vlist) {
        $qrystr .= " AND ( ";
        my $venue = shift @$vlist;
        $venue = $dbh->quote("$venue%");
        $qrystr .= " loc LIKE $venue";
        foreach $venue (@$vlist) {
            $venue = $dbh->quote("$venue%");
            $qrystr .= " or loc LIKE $venue";
        }
        $qrystr .= " )";
    }
    #print STDERR "query is $qrystr\n";

    return $qrystr;
}

sub build_single_event_query {
    my ($event_date, $venues) = @_;

    my $qmarks = join ',', map {'?'} @$venues;

    my $qrystr = 
        qq{SELECT * 
           FROM schedule 
           WHERE startday = ? 
           AND loc IN ($qmarks) 
           LIMIT 1};

    #print STDERR "query is $qrystr, params are $event_date, $venue\n";

    return $qrystr, $event_date, @$venues;
}

# see https://schema.org/DanceEvent
# and http://eceilidh.org.uk/cps/structured-data-applied-to-english-ceilidh-events.php
# a userful testing tool: https://search.google.com/structured-data/testing-tool/u/0/
#
# example data from the schedule table:
#     startday|endday|type|loc|leader|band|comments|name|stdloc|url
#     2018-01-02||ENGLISH|ASE|Bruce Hamilton|Anne Bingham Goess, Tom Lindemuth, Bill Jensen
#
# empirical experimentation shows the data is arriving here with " stripped out, so
# it's safe to just dump into the JSON
sub generate_jsonld {
    my ($dbh, $date, $venue, $type, $leader, $band, $comments) = @_;

    my $nice_dance_type = ucfirst lc $type;

    # keys to $loc hashref are: vkey|hall|address|city|zip|comment|type
    my $loc = lookup_address_for_vkey($dbh, $venue);

    my $offer_url = "https://$ENV{HTTP_HOST}$ENV{DOCUMENT_URI}";

    # questions;
    # is startDate ok without the time? might need a different table with FK
    #      from the schedule table
    return <<EOL;
<script type="application/ld+json">
{
    "\@context":"http://schema.org",
    "\@type":["Event","DanceEvent"],
    "name":"$nice_dance_type Dancing, calling by $leader to the music of $band",
    "startDate":"$date",
    "endDate":"$date",
    "organizer":
    {
        "\@context":"http://schema.org",
        "\@type":"Organization",
        "name":"Bay Areay Country Dance Society",
        "url":"https://www.bacds.org/"
    },
    "location":
    {
        "\@context":"http://schema.org",
        "\@type":"Place",
        "name":"$loc->{hall}",
        "address":
        {
            "\@type":"PostalAddress",
            "streetAddress":"$loc->{address}",
            "addressLocality":"$loc->{city}",
            "postalCode":"$loc->{zip}",
            "addressRegion":"California",
            "addressCountry":"USA"
        }
    },
    "description":"$nice_dance_type Dancing at $loc->{hall} in $loc->{city}. Everyone welcome, beginners and experts! No partner necessary. $comments",
    "image":"https://www.bacds.org/graphics/bacdsweblogomed.gif",
    "performer":
    [
        {
            "\@type":"MusicGroup",
            "name":"$band"
        },
        {
            "\@type":"Person",
            "name":"$leader"
        }
    ],
    "offers": [ {
        "\@type":"Offer",
        "name": "supporters",
        "price":"20",
        "priceCurrency": "USD",
        "url":"$offer_url",
        "validFrom":"$date",
        "availability": "please check actual prices at the door"
    },{
        "\@type":"Offer",
        "name": "non-members",
        "price":"12",
        "priceCurrency": "USD",
        "url":"$offer_url",
        "validFrom":"$date",
        "availability": "please check actual prices at the door"
    },{
        "\@type":"Offer",
        "name": "members",
        "price":"10",
        "priceCurrency": "USD",
        "url":"$offer_url",
        "validFrom":"$date",
        "availability": "please check actual prices at the door"
    },{
        "\@type":"Offer",
        "name": "students or low-income or pay what you can",
        "price":"6",
        "priceCurrency": "USD",
        "url":"$offer_url",
        "validFrom":"$date",
        "availability": "please check actual prices at the door"
    }
    ]
}
</script>
EOL

}

# vkey|hall|address|city|zip|comment|type
# ACC|Arlington Community Church|52 Arlington Avenue|Kensington|||SPECIAL
# ALB|Albany Veteran's Memorial Building|1325 Portland Avenue (off Key RouteBlvd)|Albany|||SPECIAL
sub lookup_address_for_vkey {
    my ($dbh, $vkey) = @_;

    my $sth = $dbh->prepare('SELECT * FROM venue WHERE vkey = ?') or die $dbh->errstr;

    $sth->execute($vkey) or die $sth->errstr;

    my $row = $sth->fetchrow_hashref or die "no record found in venue table for '$vkey'";

    return $row;
}

# vim: tabstop=4 shiftwidth=4 expandtab
