#!/usr/bin/perl
#
# calendar.pl -- print calendar of BACDS events.
#
# Nick Cuccia
# 2003-04-27
#
## This file is being tracked in git. DON'T MAKE IN-PLACE EDITS AND
## EXPECT THEM TO SURVIVE.
## To clone the repo, add yourself to the "git" group
#  "sudo usermod -a -G git <username>" 
## and then do "git clone /var/lib/git/bacds.org-scripts/"

use strict;
use warnings;
use CGI qw/:standard :html3 :html4 *table *Tr *td *div/;
use CGI::Carp;
use Date::Calc qw(Today Days_in_Month Day_of_Week Month_to_Text);
use DBI;


our $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
our $TEST_TODAY = $ENV{TEST_TODAY};

sub db_venue_lookup {
    my ($syear, $smon, $refloclst, $table_choice) = @_;

    my $sched_qrystr;
    my $venue_qrystr;
    my $sth;
    my @loc_lst;
    my $venue;
    my $hall;
    my $addr;
    my $city;
    my $comment;
    my %lochash;

    my $dbh = get_dbh();
    
    #
    # First, figure out what venues we're using this month
    #
    $sched_qrystr = "SELECT loc FROM $table_choice";
    $sched_qrystr .= " WHERE startday LIKE '" . $syear . "-";
    $sched_qrystr .= sprintf "%02d", $smon;
    $sched_qrystr .= "%'";
    $sched_qrystr .= " OR endday LIKE '" . $syear . "-";
    $sched_qrystr .= sprintf "%02d", $smon;
    $sched_qrystr .= "%'";
    $sth = $dbh->prepare($sched_qrystr);
    $sth->execute;
    while (($venue) = $sth->fetchrow_array()) {
        $lochash{$venue} = "" if ($venue ne "");
    }
    #
    # Next, get the descriptions for them.
    #
    foreach $venue (keys %lochash) {
        $venue_qrystr = "SELECT hall, address, city, comment FROM venue";
        $venue_qrystr .= " WHERE vkey = '" . $venue . "'";
        $sth = $dbh->prepare($venue_qrystr);
        $sth->execute;
        while (($hall,$addr,$city,$comment) = $sth->fetchrow_array()) {
            push @$refloclst, join('|',$venue,$hall,$addr,$city,$comment);
        }
    }
    sort @$refloclst;
}

sub print_venues {
    my ($start_yr, $start_mon, $table_choice) = @_;
    my $venue;

    print start_table();
    my @loc_list;
    db_venue_lookup(
        $start_yr,
        $start_mon,
        \@loc_list,
        $table_choice,
    );
    print start_Tr;
    print th({class => 'callisting'},'VENUE');
    print th({class => 'callisting'},'NAME');
    print th({class => 'callisting'},'ADDRESS');
    print th({class => 'callisting'},'CITY');
    print end_Tr;
    foreach $venue (sort @loc_list) {
        my ($key,$name,$addr,$city,$cmts);
        ($key,$name,$addr,$city,$cmts) = split('\|',$venue);
        print start_Tr;
        print td({-class => 'callisting'},$key);
        print td({-class => 'callisting'},$name);
        print td({-class => 'callisting'},$addr);
        print td({-class => 'callisting'},$city);
        print end_Tr;
        if ($cmts ne "") {
            print start_Tr;
            print td({-class => 'calcomment'});
            print td({-class => 'calcomment', -colspan => 4},em($cmts));
            print end_Tr;
        }
    }
    print end_table();
}

sub parse_url_params {
    my ($base_url) = @_;

    my ($start_year, $start_mon) = my_today();

    my $table_choice = 'schedule';

    if ($base_url =~ /\/calendars\//) {
        my @url_parts = split(/\//,$base_url);
        if ($url_parts[1] eq "calendars") {
            my $url_yr = $url_parts[2];
            my $url_mon = $url_parts[3];
            if ($url_mon =~ /^0/) {
                $_ = $url_mon;
                s/^0//;
                $url_mon = $_;
            }
            if ($url_yr eq "current") {
                ($start_year, $start_mon) = my_today();
            } else {
                if ($url_yr < $start_year) {
                    $table_choice = 'schedule'.$url_yr;
                }

                $start_year = $url_yr;
                $start_mon = $url_mon;
                
            }
        } else {
            ($start_year, $start_mon) = my_today();
        }
    }
    return $start_year, $start_mon, $table_choice;
}

sub print_schedule {
    my ($start_yr, $start_mon, $schedref) = @_;
    my $event;
    my %taghash;
    my $div_start;

    $div_start = 0;


    my ($tyear, $tmon, $tday) = my_today();

    print start_table();
    print start_Tr;
    print th({class => 'caltitle'},'DATE(S)');
    print th({class => 'caltitle'},'STYLE');
    print th({class => 'caltitle'},'LOCATION');
    print th({class => 'caltitle'},'CALLER(S)<br>TEACHER(S)');
    print th({class => 'caltitle', -align=>'center'},'MUSICIANS');
    print end_Tr;
    foreach $event (@$schedref) {
        my $start;
        ($start) = split('\|',$event);
        $taghash{$start} = 0;
    }
    foreach $event (@$schedref) {
        my ($stday,$endday,$typ,$loc,$ldr,$band,$cmts);
        my ($tsyr, $tsmon, $tsday);
        my ($teyr, $temon, $teday);
        my ($ttemon, $ttsmon);
        my $txtdate;
        ($stday,$endday,$typ,$loc,$ldr,$band,$cmts) = split('\|',$event);
        ($tsyr,$tsmon,$tsday) = split('-',$stday);
        $ttsmon = Month_to_Text($tsmon);
        $txtdate = $ttsmon . '&nbsp;' . $tsday;
        $tsday =~ s/^0//;
        if ($endday ne '') {
            ($teyr,$temon,$teday) = split('-',$endday);
            $ttemon = Month_to_Text($temon);
            $txtdate .= '&nbsp;to&nbsp;' . $ttemon . '&nbsp;' . $teday;
        }
        if ($tsyr == $tyear && $tsmon == $tmon && $tsday == $tday) {
            if ($div_start == 0) {
                print start_div({-class => 'tonight'});
                $div_start = 1;
            }
        } else {
            if ($div_start == 1) {
                print end_div;
                $div_start = 0;
            }
        }
        print start_Tr;
        print start_td({-class => 'callisting'});
        print a({-name => $stday},'')
            if ($taghash{$stday}++ == 0);
        print $txtdate;
        print end_td;
        print td({-class => 'callisting'},$typ);
        print td({-class => 'callisting'},$loc);
        # edb 30may2010: tighten up comments in listing
        if (0 && $cmts) {
            print td({-class => 'callisting', -rowspan=>2},$ldr);
            print td({-class => 'callisting', -rowspan=>2},$band);
        } else {
            print td({-class => 'callisting'},$ldr);
            print td({-class => 'callisting'},$band);
        }
        print end_Tr;
        # edb 18jun2020: indent comments to tie to listing
        if ($cmts) {
            print start_Tr( {-class=>'calcomment'} );
            print td({-class => 'calcomment'});
            print td({-class => 'calcomment', -colspan => 4},em($cmts));
            print end_Tr;
        }
    }
    print end_table();
}


sub print_start_of_mon {
    my ($mon, $yr) = @_;

    print start_table(-class => 'calendar');
    print start_Tr();
    print th(
        {
            -colspan => 7,
            -class => 'calendar_title'
        },
        Month_to_Text($mon) . ' ' . $yr
    );
    print end_Tr();
    print start_Tr();
    print th({-class => 'calendar'},"Su");
    print th({-class => 'calendar'},"M");
    print th({-class => 'calendar'},"Tu");
    print th({-class => 'calendar'},"W");
    print th({-class => 'calendar'},"Th");
    print th({-class => 'calendar'},"F");
    print th({-class => 'calendar'},"Sa");
    print end_Tr();
}


sub print_end_of_mon {
    print end_Tr();
    print end_table();
}

sub print_date {
    my ($dow, $cyr, $cmon, $cdom, $datelnk) = @_;
    my $dstr;

    my ($tyear, $tmon, $tday) = my_today();

    print start_Tr() if ($dow == 0);
    print start_td({-class => 'calendar'});
    if ($cyr == $tyear && $cmon == $tmon && $cdom == $tday) {
        print start_div({-class => 'tonight'});
    }
    print a({-href => $datelnk},$cdom) if ($datelnk ne "");
    print $cdom if ($datelnk eq "");
    if ($cyr == $tyear && $cmon == $tmon && $cdom == $tday) {
        print end_div;
    }
    print end_td;
}

sub print_tab_calendar {
    my ($cur_start_year, $cur_start_mon, $schedref) = @_;

    my $cur_days_in_mon;
    my $cur_day_of_mon;
    my $cur_day_of_wk;
    my $days_in_wk = 7;
    my $dow;
    my $datelnk;
    my $datestr;
    my %taghash;
    my $event;

    foreach $event (@$schedref) {
        my $start;
        ($start) = split('\|',$event);
        $taghash{$start} = 'YES';
    }

    ##
    ## get important values for the given month
    ##
    # Days in current month
    $cur_days_in_mon = Days_in_Month($cur_start_year, $cur_start_mon);
    # We're basing everything on the first day of the month
    $cur_day_of_mon = 1;
    # and the first day of the week
    $cur_day_of_wk = Day_of_Week(
        $cur_start_year,
        $cur_start_mon,
        $cur_day_of_mon
    );

    # print start of month
    print_start_of_mon($cur_start_mon,$cur_start_year);

    ## If the current isn't Sunday, print a partial week;
    ## otherwise, fall through and loop through full weeks.
    if (($cur_day_of_wk % $days_in_wk) != 0) {
        $dow = 0;
        while ($dow != $cur_day_of_wk) {
            print_empty($dow);
            $dow++;
        }
        while ($dow < $days_in_wk) {
            my $datekey;
                my $datekey2;  # make resilience against days <10
            $datelnk = '';
            $datekey =  $cur_start_year . '-';
            $datekey .= '0' if ($cur_start_mon < 10);
            $datekey .= $cur_start_mon . '-';
                $datekey2 = $datekey;
            $datekey .= '0' if ($cur_day_of_mon < 10);
            $datekey .= $cur_day_of_mon;
                $datekey2 .= $cur_day_of_mon;
            $datelnk =  '#' . $datekey if ($taghash{$datekey}||'' eq 'YES');
            $datelnk =  '#' . $datekey2 if ($taghash{$datekey2}||'' eq 'YES');
            print_date(
                $dow,
                $cur_start_year,
                $cur_start_mon,
                $cur_day_of_mon,
                $datelnk
            );
            $dow++;
            $cur_day_of_mon++;
        }
        print_end_of_wk();
    }

    ##
    ## and print rest of the month
    ##
    while ($cur_day_of_mon <= $cur_days_in_mon) {
        $dow = 0;
        while ($dow < $days_in_wk) {
            if ($cur_day_of_mon <= $cur_days_in_mon) {
                my $datekey;
                $datelnk = '';
                $datekey =  $cur_start_year . '-';
                $datekey .= '0' if ($cur_start_mon < 10);
                $datekey .= $cur_start_mon . '-';
                $datekey .= '0' if ($cur_day_of_mon < 10);
                $datekey .= $cur_day_of_mon;
                $datelnk =  '#' . $datekey if ($datekey && $taghash{$datekey} && $taghash{$datekey} eq 'YES');
                print_date (
                    $dow,
                    $cur_start_year,
                    $cur_start_mon,
                    $cur_day_of_mon,
                    $datelnk
                );
            }
            $dow++;
            $cur_day_of_mon++;
        }
        print_end_of_wk();
    }
    print_end_of_mon();
}

#
sub print_empty {
    my ($dow) = @_;

    print start_Tr() if ($dow == 0);
    print td({-class => 'calendar'},'  ');
}


#
sub print_end_of_wk {
    print end_Tr();
}

#

########
##### Database routines -- Should modularize these
########


sub db_sched_lookup {
    my ($syear, $smon, $table_choice) = @_;

    my @schedule;

    my $qrystr;
    my $sth;
    my ($stday, $endday, $typ, $loc, $ldr, $band, $cmts);
    my @mlst;

    my $dbh = get_dbh();
    #
    # First, figure out what dances are being danced this month
    $qrystr = "SELECT ".
     "startday, endday, type, loc, leader, band, comments FROM $table_choice";
    $qrystr .= " WHERE startday LIKE '" . $syear . "-";
    $qrystr .= sprintf "%02d", $smon;
    $qrystr .= "%'";
    $qrystr .= " OR endday LIKE '" . $syear . "-";
    $qrystr .= sprintf "%02d", $smon;
    $qrystr .= "%'";
    $sth = $dbh->prepare($qrystr);
    $sth->execute;
    while (($stday,$endday,$typ,$loc,$ldr,$band,$cmts) = $sth->fetchrow_array()) {
        if ($cmts) {
            $cmts =~ s/<q>/"/g;
            push @schedule, join('|',$stday,$endday,$typ,$loc,$ldr,$band,$cmts);
        } else {
            push @schedule, join('|',$stday,$endday,$typ,$loc,$ldr,$band);
        }
    }

    return \@schedule;
}

sub main {

    print header();

    my $base_url = url(-absolute => 1);

    my ($start_year, $start_mon, $end_year, $end_mon, $table_choice)
        = parse_url_params($base_url);


    print start_html(
        -title => 'BACDS Calendar generator',
        -style => {
            -src => '/css/calendar.css'
        }
    );
    print h1("BACDS Events Calendar");

    my $schedule = db_sched_lookup(
        $start_year,
        $start_mon,
        $table_choice,
    );

    print_tab_calendar(
        $start_year,
        $start_mon,
        $schedule,
    );
    print h1("Schedule of Events");
    print_schedule(
        $start_year,
        $start_mon,
        $schedule,
    );
    print h1("Dance Venues");
    print_venues(
        $start_year,
        $start_mon,
        $table_choice,
    );
    print end_html();

}

sub my_today {
    my ($tyear, $tmon, $tday) =
        $TEST_TODAY
        ? split '-', $TEST_TODAY
        : Today();
    return $tyear, $tmon, $tday;
}

sub get_dbh {
    return DBI->connect(
        qq[DBI:CSV:f_dir=$CSV_DIR;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\], '', ''
    );
}

main();
