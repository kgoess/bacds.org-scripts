#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getstyles.pl" -->
##
## This includes camps (where endday IS NOT null)
#
## Set TEST_CSV_DIR in your environment to use something else
## besides '/var/www/bacds.org/public_html/data'.

use strict;

use DateTime;
use Template;

use bacds::Model::Event;
use bacds::Utils qw/today_ymd get_dbix_test_cookie/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

main();

sub main {

    my ($style, $venue, $end_date) = parse_querystring();

    my ($styles);

    if (get_dbix_test_cookie()) {
        $styles = get_styles_dbix($style, $venue, $end_date);
    } else {
        $styles = get_styles_csv($style, $venue, $end_date);
    }

    print_results($styles);
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

sub get_styles_dbix {
    my ($style, $vkey, $end_date) = @_;

    my $dbh = get_dbh();

    my %stylehash;

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
        my $styles = $event->styles;
        while (my $style = $styles->next) {
            $stylehash{$style->name} = 1;
        }
    }

    my @styles = sort keys %stylehash;
    return \@styles;
}

sub get_styles_csv {
    my ($style, $venue, $end_date) = @_;

    my $today = today_ymd();

    my @events = bacds::Model::Event->load_all(
        after => $today,
        before => $end_date, # optional
        venue => $venue, # optional
        style => $style, # optional
        without_end_date => 0,
        includes_leader => 1,
    );

    my %stylehash = ();
    foreach my $event (@events) {
        my $type = $event->type;

        my $temp_type;
        $temp_type = $type;
        $temp_type = 'SPECIAL' if $type =~ /SPECIAL/;
        $temp_type = 'WOODSHED' if $type =~ /WOODSHED/;
        $temp_type = 'CAMP' if $type =~ /CAMP/;
        $stylehash{$temp_type} = 
            $temp_type if (! $stylehash{$type} );
    }

    my @styles = sort keys %stylehash;

    return \@styles;
}

sub print_results {
    my ($styles) = @_;

    my $tt = Template->new();

    my $template = <<'EOL';
<select name="style">
    <option value="">ALL STYLES</option>
    [%- FOREACH style IN styles %]
        <option value="[% style | html %]">[% style | html %]</option>
    [%- END %]
</select>
EOL
    $tt->process(\$template, { styles => $styles } )
        || die $tt->error(), "\n";
}


