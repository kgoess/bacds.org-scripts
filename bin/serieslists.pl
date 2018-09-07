#!/usr/bin/perl -w
##
## Print out dances for each series.
##
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
    ? build_single_event_query($single_event, shift @vlist)
    : build_upcoming_events_query(\@slist, \@vlist, $dbh); 

##
## Make the query
##
my $sth = $dbh->prepare($query_string) or die $dbh->errstr;
$sth->execute(@bind_params);

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
    $type = "";
    print $trailer;
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
    my ($event_date, $venue) = @_;

    my $qrystr = q{SELECT  * FROM schedule WHERE startday = ? AND loc = ?};

    #print STDERR "query is $qrystr, params are $event_date, $venue\n";

    return $qrystr, $event_date, $venue;
}

# vim: tabstop=4 shiftwidth=4 expandtab
