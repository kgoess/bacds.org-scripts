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
#
# The calendars page is set up so that every entry in recent years (eg
# /calendars/2022/01 ) has an index.pl which is a symlink:
#
#      index.pl -> ../../../../cgi-bin/calendar2.pl
#
# The access logs won't show any direct hits to cgi-bin/calendar2.pl.

use strict;
use warnings;
use CGI qw/:standard :html3 :html4 *table *Tr *td *div/;
use CGI::Carp;
use Data::Dump qw/dump/;
use Date::Calc qw(Today Days_in_Month Day_of_Week Month_to_Text);
use DateTime;
use DBI;

use bacds::Model::Event;
use bacds::Model::Venue;
use bacds::Scheduler::Model::Calendar;


our $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
our $TEST_TODAY = $ENV{TEST_TODAY};

# Note this only works for the schema starting in early 2022
# but I think that's ok, the venue list isn't as important
# when doing historical digging.
sub db_venue_lookup {
    my ($syear, $smon, $table_choice) = @_;

    $table_choice =~ s/[^a-z0-9-]//g;

    my %lochash;

    my $dbh = get_dbh();

    my $start_date = sprintf("%4d-%02d-01", $syear, $smon);
    my $end_date = DateTime->new(
        year       => $syear,
        month      => $smon,
        day        => 1,
    )->add(months => 1)->ymd;

    #
    # First, figure out what venues we're using this month
    #
    my @events = bacds::Model::Event->load_all(
        after => $start_date,
        before => $end_date,
    );

    my (@venue_list, %seen);

    foreach my $event (@events) {
        my $vkey = $event->loc;
        next if $seen{$vkey}++;
        my $venue = bacds::Model::Venue->load(vkey => $vkey);
        push @venue_list, join '|',
            map { $venue->$_ } qw/
                vkey
                hall
                address
                city
                comment
            /;
    }
    sort @venue_list
}

sub print_venues {
    my ($start_yr, $start_mon, $table_choice) = @_;
    my $venue;

    print start_table();
    my @loc_list;
    #if (cookie('DBIX_TEST')) {
        @loc_list = bacds::Scheduler::Model::Calendar->load_venue_list_for_month($start_yr, $start_mon);
    #} else {
    #    @loc_list = db_venue_lookup(
    #        $start_yr,
    #        $start_mon,
    #        $table_choice,
    #    );
    #}
    print start_Tr;
    print th({class => 'callisting'},'VENUE');
    print th({class => 'callisting'},'NAME');
    print th({class => 'callisting'},'ADDRESS');
    print th({class => 'callisting'},'CITY');
    print end_Tr;
    foreach $venue (sort @loc_list) {
        my ($key,$name,$addr,$city,$cmts) = split('\|',$venue);
        $cmts //= '';
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

    # allow unit tests to override
    my $table_choice = $ENV{TEST_TABLE_CHOICE} || 'schedule';

    if ($base_url =~ /\/calendars\//) {
        my @url_parts = split(/\//,$base_url);
        if ($url_parts[1] eq "calendars") {
            my $url_yr = $url_parts[2];
            my $url_mon = $url_parts[3];
            if ($url_yr eq "current") {
                ($start_year, $start_mon) = my_today();
            } else {
                # sanitize and limit the request data
                $url_yr =~ s/[^0-9]//g;
                $url_yr =~ s/^([0-9]{4}).*/$1/;
                $url_mon =~ s/[^0-9]//g;
                $url_mon =~ s/^([0-9]{2}).*/$1/;

                # if we've sanitized them all away, replace them
                # with something useful/safe
                if (!($url_yr && $url_mon)) {
                    ($url_yr, $url_mon) = my_today();
                }
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

    $start_mon =~ s/^0//; # remove any leading zero

    return $start_year, $start_mon, $table_choice;
}

sub print_schedule {
    my ($start_yr, $start_mon, $schedref) = @_;

    my %taghash;

    my $div_start = 0;


    my ($tyear, $tmon, $tday) = my_today();

    print start_table();
    print start_Tr;
    print th({class => 'caltitle'},'DATE(S)');
    print th({class => 'caltitle'},'STYLE');
    print th({class => 'caltitle'},'LOCATION');
    print th({class => 'caltitle'},'CALLER(S)<br>TEACHER(S)');
    print th({class => 'caltitle', -align=>'center'},'MUSICIANS');
    print end_Tr;

    # $event is an OldEvent defined in bacds::Scheduler::Model::Calendar
    foreach my $event (@$schedref) {
        my $start = $event->startday;
        $taghash{$start} = 0;
    }


    foreach my $event (@$schedref) {
        my ($stday, $endday, $typ, $loc, $ldr, $band, $cmts, $is_canceled, $musos)
            = map { $event->$_ } qw/startday endday type loc leader band comments is_canceled musos/;
        my ($tsyr, $tsmon, $tsday) = split('-',$stday);
        my $ttsmon = Month_to_Text($tsmon);
        my $txtdate = $ttsmon . '&nbsp;' . $tsday;
        $tsday =~ s/^0//;
        if ($endday ne '') {
            my ($teyr, $temon, $teday) = split('-',$endday);
            my $ttemon = Month_to_Text($temon);
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
        my $listing_class = 'callisting' . ($is_canceled ? ' calcanceled' : '');
        my $comment_class = 'calcomment' . ($is_canceled ? ' calcanceled' : '');
        print start_Tr;
        print start_td({-class => $listing_class});
        print a({-name => $stday},'')
            if ($taghash{$stday}++ == 0);
        print $txtdate;
        print end_td;
        print td({-class => $listing_class},$typ);
        print td({-class => $listing_class},$loc);
        # edb 30may2010: tighten up comments in listing
        if (0 && $cmts) {
            print td({-class => $listing_class, -rowspan=>2},$ldr);
            print td({-class => $listing_class, -rowspan=>2},$band);
        } else {
            my $talent = '';
            $talent = $band;
            if ($band && $musos) {
                $talent .= ', ';
            }
            $talent .= $musos;
            print td({-class => $listing_class},$ldr);
            print td({-class => $listing_class},$talent);
        }
        print end_Tr;
        # edb 18jun2020: indent comments to tie to listing
        if ($cmts) {
            print start_Tr( {-class=> $comment_class} );
            print td({-class => $comment_class});
            print td({-class => $comment_class, -colspan => 4},em($cmts));
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

    my $days_in_wk = 7;
    my %taghash;

    foreach my $event (@$schedref) {
        # $event is an OldEvent defined in bacds::Scheduler::Model::Calendar
        my $start = $event->startday;
        $taghash{$start} = 'YES';
    }

    ##
    ## get important values for the given month
    ##
    # Days in current month
    my $cur_days_in_mon = Days_in_Month($cur_start_year, $cur_start_mon);
    # We're basing everything on the first day of the month
    my $cur_day_of_mon = 1;
    # and the first day of the week
    my $cur_day_of_wk = Day_of_Week(
        $cur_start_year,
        $cur_start_mon,
        $cur_day_of_mon
    );

    # print start of month
    print_start_of_mon($cur_start_mon,$cur_start_year);

    ## If the current isn't Sunday, print a partial week;
    ## otherwise, fall through and loop through full weeks.
    if (($cur_day_of_wk % $days_in_wk) != 0) {
        my $dow = 0;
        while ($dow != $cur_day_of_wk) {
            print_empty($dow);
            $dow++;
        }
        while ($dow < $days_in_wk) {
            my $datekey;
                my $datekey2;  # make resilience against days <10
            my $datelnk = '';
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
        my $dow = 0;
        while ($dow < $days_in_wk) {
            if ($cur_day_of_mon <= $cur_days_in_mon) {
                my $datekey;
                my $datelnk = '';
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


sub db_sched_lookup {
    my ($syear, $smon, $table_choice) = @_;

    $table_choice =~ s/[^a-z0-9-]//g;

    if ($table_choice =~ /^(?: schedule | schedule2022 )$/x) {
        return _db_sched_lookup_new($syear, $smon, $table_choice);
    } else {
        return _db_sched_lookup_old($syear, $smon, $table_choice);
    }
}

# this returns a list of OldEvent objects, an internal class in
# bacds::Scheduler::Model::Calendar that's just some accessors
sub _db_sched_lookup_new {
    my ($syear, $smon, $table_choice) = @_;

    my @schedule;

    my @events = bacds::Scheduler::Model::Calendar->load_events_for_month($syear, $smon);

    return \@events;
}

# would take some work to match the older CSV schemas,
# so let's just wait until after the full migration to mysql
sub _db_sched_lookup_old {
    my ($syear, $smon, $table_choice) = @_;
    my @schedule;

    my $dbh = get_dbh();
    #
    # First, figure out what dances are being danced this month
    my $qrystr = <<EOL;
        SELECT
            startday, endday, type, loc, leader, band, comments
        FROM $table_choice
        WHERE startday LIKE ?
           OR endday LIKE ?
EOL
    # not sure endday is doing anything here any more since startdate and
    # endday are both the same?

    my $date_param = sprintf "%04d-%02d%%", $syear, $smon;
    my $sth = $dbh->prepare($qrystr)
        or die "can't prepare $qrystr: ".$dbh->errstr;
    $sth->execute($date_param, $date_param);
    while (my ($stday, $endday, $typ, $loc, $ldr, $band, $cmts) = $sth->fetchrow_array()) {
        $cmts //= '';
        $cmts =~ s/<q>/"/g;

        # OldEvent is defined in bacds::Scheduler::Model::Calendar
        my $event = OldEvent->new(
            startday => $stday,
            endday   => $endday,
            type     => $typ,
            loc      => $loc,
            leader   => $ldr,
            band     => $band,
            comments => $cmts,
            #musos => , # no musos in the old schema
        );
        push @schedule, $event;
    }

    return \@schedule;
}

sub main {

    print header();

    my $base_url = url(-absolute => 1);

    my ($start_year, $start_mon, $table_choice) = parse_url_params($base_url);

    print start_html(
        -title => 'BACDS Calendar generator',
        -style => [
            { -src => '/css/calendar.css' },
            #cookie('DBIX_TEST') ? { -src => '/css/beta-test-dbix.css' } : (),
        ],
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
