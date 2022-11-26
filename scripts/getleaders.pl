#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getleaders.pl" -->
##
## note that this script doesn't look at QUERY_STRING
#
## Set TEST_CSV_DIR in your environment to use something else
## besides '/var/www/bacds.org/public_html/data'.

use strict;

use CGI::Cookie;
use Template;

use bacds::Model::Event;
use bacds::Utils qw/today_ymd get_dbix_test_cookie/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

main();

sub main {

    my ($caller_names, $needs_html_escaping);

    if (get_dbix_test_cookie()) {
        ($caller_names, $needs_html_escaping) = get_leaders_dbix();
    } else {
        ($caller_names, $needs_html_escaping)= get_leaders_csv();
    }

    print_results($caller_names, $needs_html_escaping);
}


sub get_leaders_csv {
    my @events = bacds::Model::Event->load_all(
        after => today_ymd(),
        without_end_date => 1,
        includes_leader => 1,
    );

    my (%leaderhash);
    foreach my $event (@events) {
        my $leader = $event->leader;
        #
        # If leader has a location code, nuke it
        #
        $leader =~ s/ \[[^\]]+\].*//g;
        my @clst = split(/, /, $leader);
        foreach my $i (@clst) {
            $leaderhash{$i} = $i if ! $leaderhash{$i};
        }
    }
    my @leader_names = sort keys %leaderhash;
    my $needs_html_escaping = 0;
    return \@leader_names, $needs_html_escaping;
}

sub get_leaders_dbix {
    my $dbh = get_dbh();

    my $rs = $dbh->resultset('Event')->search({
            start_date => { '>=' => today_ymd },
    });

    my %leaderhash;
    while (my $event = $rs->next) {
        my $callers = $event->callers
            or next;
        while (my $caller = $callers->next) {
            $leaderhash{$caller->name} = 1;
        }
    }

    my @leader_names = sort keys %leaderhash;
    my $needs_html_escaping = 1;
    return \@leader_names, $needs_html_escaping;
}

sub print_results {
    my ($leader_names, $needs_html_escaping) = @_;

    my $tt = Template->new();

    my $escape_html = $needs_html_escaping
        ? ' | html'
        : '';

    # the "leader" values are already HTML-escaped
    my $template = <<EOL;
<select name="caller">
    <option value="">ALL LEADERS</option>
    [%- FOREACH caller IN callers %]
        <option value="[% caller $escape_html %]">[% caller $escape_html %]</option>
    [%- END %]
</select>
EOL
    $tt->process(\$template, { callers => $leader_names } )
        || die $tt->error(), "\n";

}


