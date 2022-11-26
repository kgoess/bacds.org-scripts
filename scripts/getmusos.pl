#!/usr/bin/perl -w
##
## public_html/dancefinder/content.html:<!--#include virtual="/scripts/getmusos.pl" -->
##
## getmusos.pl ignores QUERY_STRING
##
## getmusos.pl is buggy, the data in "band" includes all kinds of text trash,
## so the output of this includes all kinds of trash, like this:
##
##    <option value="Dance 2:30">Dance 2:30</option>
##
## 'musos" should be a separate table, many-to-one
#
## Set TEST_CSV_DIR in your environment to use something else
## besides '/var/www/bacds.org/public_html/data'.

use strict;

use Template;

use bacds::Model::Event;
use bacds::Utils qw/today_ymd get_dbix_test_cookie/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

main();


sub main {

    my ($bands, $musos, $needs_html_escaping);

    if (get_dbix_test_cookie()) {
        ($bands, $musos) = get_bands_and_musos_dbix();
        $needs_html_escaping = 1;
    } else {
        ($bands, $musos) = get_bands_and_musos_csv();
        $needs_html_escaping = 0;
    }

    print_results($bands, $musos, $needs_html_escaping);
}

sub get_bands_and_musos_dbix {
    my $dbh = get_dbh();

    my $rs = $dbh->resultset('Event')->search({
        start_date => { '>=' => today_ymd },
    });

    my (%bandhash, %musohash);

    while (my $event = $rs->next) {
        if (my $bands = $event->bands) {
            # grab the bands
            while (my $band = $bands->next) {
                $bandhash{$band->name} = 1;
                # and the band members
                if (my $talentii = $band->talents) {
                    while (my $talent = $talentii->next) {
                        $musohash{$talent->name} = 1;
                    }
                }
            }
        }
        # and any unattached musos
        if (my $talentii = $event->talent) {
            while (my $talent = $talentii->next) {
                $musohash{$talent->name} = 1;
            }
        }
    }
    my @bands = sort keys %bandhash;
    my @musos = sort keys %musohash;
    return \@bands, \@musos;
}


sub get_bands_and_musos_csv {
    my @events = bacds::Model::Event->load_all(
        after => today_ymd(),
        without_end_date => 1,
        includes_leader => 1,
    );

    ##
    ##
    ## Pull out band and muso names
    ##
    my (%bandhash, %musohash);

    foreach my $event (@events) {
        my $band = $event->band;
        my $guest = "";
        my $mstr = "";
        my $bandname = "";
        $_ = $band;
        s/ \[[^\]]+\]//g;			# Remove location
        s/ with /, /g;				# ' with ' same as ', ' 
        s/ and Friend[s]*//g;			# remove 'and Friend[s]'
        s/Open Band led by //;			# remove "Open Band"
        s/, and /, /;				# ' and ' same as ', '
        s/ and /, /;				# ' and ' same as ', '
        s/TBA//;				# remove "TBA"
        s/\<a.*\<q\>\>//;			# remove opening "<a>"
        s/\<\\a\>//;				# remove closing "<\a>"
        $band = $_;
    #	print "Transformed line:  " . $band . "\n";
        #
        # We've removed and cleaned up the cruft.  Now let's try to 
        #  parse out the goodies.
        #
        # At this point, we have one of:
        #
        #	muso, muso, muso, ...
        #	band (muso ...)
        #	band (muso ...), guest
        $mstr = $_;
        ($bandname,$mstr,$guest) = /(.+) \((.+)\), (.+)/ if /\),/;
        ($bandname,$mstr) = /(.+) \((.+)\)/ if /\)$/;
        $mstr = $_ if ! /\)/;
    #	print "Parsed line:  ";
    #	print "bandname=$bandname	" if $bandname;
    #	print "mstr=$mstr	" if $mstr;
    #	print "guest=$guest	" if $guest;
    #	print "\n";
        #
        # We should be parsed now.  Now build our lists.
        #
        my @mlst = split(/, /,$mstr);
        foreach my $i (@mlst) {
            $musohash{$i} = $i if ! $musohash{$i};
        }
        $bandhash{$bandname} = $bandname if $bandname;
        $musohash{$guest} = $guest if ($guest && ! $musohash{$guest});
    }

    # Manually insert open band
    $bandhash{"Open Band"} = "Open Band";

    my @bands = sort keys %bandhash;
    my @musos = sort keys %musohash;

    return \@bands, \@musos;
}


sub print_results {
    my ($bands, $musos, $needs_html_escaping) = @_;

    my $tt = Template->new();

    my $escape_html = $needs_html_escaping
        ? ' | html'
        : '';

    my $template = <<EOL;
<select name="muso">
    <option value="">ALL BANDS AND MUSICIANS</option>
    [%- FOREACH band IN bands %]
        <option value="[% band $escape_html %]">[% band $escape_html %]</option>
    [%- END %]
    <option value=""></option>
    [%- FOREACH muso IN musos %]
        <option value="[% muso $escape_html %]">[% muso $escape_html %]</option>
    [%- END %]
</select>
EOL

    $tt->process(\$template, {
        bands => $bands,
        musos => $musos,
    }) || die $tt->error(), "\n";
}



