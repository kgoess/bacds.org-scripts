#!/usr/bin/perl -w
##
## Get list of venues
##
## dancefinder/content.html <!--#include virtual="/scripts/getvenues.pl" -->
#
## Set TEST_CSV_DIR in your environment to use something else
## besides '/var/www/bacds.org/public_html/data'.

use strict;

use DateTime;
use Template;

use bacds::Model::Event;
use bacds::Model::Venue;
use bacds::Utils qw/today_ymd get_dbix_test_cookie/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

main();

sub main {

    my ($style, $venue, $end_date) = parse_querystring();

    my ($venuehash);

    if (get_dbix_test_cookie()) {
        $venuehash = get_venues_dbix($style, $venue, $end_date);
    } else {
        $venuehash = get_venues_csv($style, $venue, $end_date);
    }

    print_results($venuehash);
}


sub parse_querystring {
    my ($style, $venue, $numdays, $end_date);

    my @vals = split(/&/,$ENV{'QUERY_STRING'}) if $ENV{'QUERY_STRING'};
    foreach my $i (@vals) {
        my ($varname, $data) = split(/=/,$i);
        $data =~ s/[^A-Z0-9]//g;
        $style = $data if $varname eq "style";
        $venue = $data if $varname eq "venue";
        $numdays = $data if $varname eq "numdays";
    }

    if ($numdays) {
        my $today = today_ymd();
        my ($today_year, $today_mon, $today_day) = split '-', $today;

        ##
        ## Figure out what the date will be in a week.
        ##
        $end_date = DateTime
            ->new(year => $today_year, month => $today_mon, day => $today_day)
            ->add(days => 8)
            ->ymd;
    }

    return $style, $venue, $end_date;
}

# arguably all this searching stuff could be in
# bacds::Schedule::Model::something?
sub get_venues_dbix {
    my ($style, $vkey, $end_date) = @_;

    my $dbh = get_dbh();

    my %venuehash;

    my $today = today_ymd();

    my (@search_args, @related_tables);
    if ($style) {
        push @search_args, 'style.name' => $style;
        push @related_tables, {'event_styles_maps' => 'style'};
    }
    if ($vkey) {
        my $venue = $dbh->resultset('Venue')->search({
            vkey => $vkey
        })->single
            or die "no such venue '$vkey'";
        push @search_args, 'venue.vkey' => $vkey;
        push @related_tables, {'event_venues_maps' => 'venue'};
    }
    # yes, $end_date is the end of the range for "start_date"
    if ($end_date) {
        push @search_args, start_date => { '<=' => $end_date };
    }


    my $rs = $dbh->resultset('Event')->search(
        {
            start_date => { '>=' => today_ymd },
            @search_args,
        },
        {
            join => \@related_tables,
            prefetch => \@related_tables,
        },
    );

    while (my $event = $rs->next) {
        my $venues = $event->venues;
        while (my $venue = $venues->next) {
            $venuehash{$venue->vkey} =
                $venue->city . ' -- ' .$venue->hall_name;
        }
    }
    return \%venuehash;
}

sub get_venues_csv {
    my ($style, $venue, $end_date) = @_;

    my (%venuehash);

    my $today = today_ymd();

    my @events = bacds::Model::Event->load_all(
        after => $today,
        ($end_date ? (before => $end_date) : ()),
        venue => $venue,
        style => $style,
        includes_leader => 1,
        without_end_date => 1,
    );

    foreach my $event (@events) {
        my $loc = $event->loc;
        my ($norm_venue, $norm_city) = get_hall_name_city($loc);
        $venuehash{$loc} = $norm_city . " -- " . $norm_venue if ! $venuehash{$loc};
    }

    return \%venuehash;
}

sub get_hall_name_city {
	my ($vkey) = @_;

    if (my $venue = bacds::Model::Venue->load(vkey => $vkey)) {
        return $venue->hall, $venue->city;
    }
    return();
}



sub print_results {
    my ($venuehash) = @_;

    my $tt = Template->new();

    my $template = <<'EOL';
<select name="venue">
    <option value="">ALL LOCATIONS</option>
    [%- FOREACH vkey IN venuehash.keys.sort %]
        <option value="[% vkey | html %]">[% venuehash.$vkey | html %]</option>
    [%- END %]
</select>
EOL

    $tt->process(\$template, { venuehash => $venuehash } )
        || die $tt->error(), "\n";
}

