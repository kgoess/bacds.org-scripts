#!/usr/bin/perl -w
##
## Print out dances for each series.
##
use strict;
use Time::Local;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year Day_of_Week_to_Text Today);
use DBI;

my ($style, $styles, $venue, $day, $day2, $day3, $day4, $day5, $day6, $day7);
my ($venues);
my ($wday);
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
    $day = $data if $varname eq "day";
    $day2 = $data if $varname eq "day2";
    $day3 = $data if $varname eq "day3";
    $day4 = $data if $varname eq "day4";
    $day5 = $data if $varname eq "day5";
    $day6 = $data if $varname eq "day6";
    $day7 = $data if $varname eq "day7";
}
my @vlist = split ',', $venues if $venues;
my @slist = split ',', $styles if $styles;

my $today = sprintf "%4.4d-%2.2d-%2.2d", Today();

##
## Now build our query string
##
my $qrystr = "SELECT * FROM schedule";
$qrystr .= " WHERE startday >= '$today'";
if ($style) {
    $qrystr .= " AND type LIKE '%$style%'";
}
if (@slist) {
    $qrystr .= " AND ( ";
    my $style = shift @slist;
    $qrystr .= " type LIKE '%$style%'";
    foreach $style (@slist) {
        $qrystr .= " or type LIKE '%$style%'";
    }
    $qrystr .= " )";
}
if (@vlist) {
    $qrystr .= " AND ( ";
    my $venue = shift @vlist;
    $qrystr .= " loc LIKE '$venue%'";
    foreach $venue (@vlist) {
        $qrystr .= " or loc LIKE '$venue%'";
    }
    $qrystr .= " )";
}
if ($venue) {
    $qrystr .= " AND ( loc LIKE '$venue%' )";
}

#print "query is $qrystr\n";

##
## Set up the table and make the query
##
my $csv_dir = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $dbh = DBI->connect(qq[DBI:CSV:f_dir=$csv_dir;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');
my $sth = $dbh->prepare($qrystr);
$sth->execute();

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
#print "days are " . $day_map{$day} . " and " . $wday . "\n";
        
     $trailer = "\n";
        
    if ($day_map{$day} eq $wday  ||
       $day2 && ($wday && $day_map{$day2} eq $wday)  || 
       $day3 && ($wday && $day_map{$day3} eq $wday)  || 
       $day4 && ($wday && $day_map{$day4} eq $wday)  || 
       $day5 && ($wday && $day_map{$day5} eq $wday)  || 
       $day6 && ($wday && $day_map{$day6} eq $wday)  || 
       $day7 && ($wday && $day_map{$day7} eq $wday)
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
#print "days are " . $day_map{$day2} . " and " . $wday . "\n" if $day2 ne "";
#    if ($day2 && ($wday && ($day_map{$day2} eq $wday))) {
#        print "<a name=\"$startday-$type\"></a>\n";
#        print "<p class=\"dance\">\n";
#        print "<b class=\"date\">";
#        print $mon_lst[$date_mon-1] . " " . $date_day . "</b><br />\n";#
#        if ($leader) {
#              print "Caller:  " . $leader . "<br />\n";
#        }
#        print "Band:  " . $band . "<br /><br />\n" if $band;
#        print "</p>\n";
#        if ($comments && $comments ne "") {
#            print "<p class=\"comment\">\n";
#            print "$comments\n";
#            print "</p>\n";
#        }
#    }
    $type = "";
    print $trailer;
}
# vim: tabstop=4 shiftwidth=4 expandtab
