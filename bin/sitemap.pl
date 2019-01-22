#!/usr/bin/perl -w

=head sitemap.pl

Actually, this isn't currently in use. Google thinks
the canonical page is the http page not the https page,
that was the source of the problems. AFAICT it doesn't
need a sitemap file.

TODO:
 - add to cron
 - add sitemap-index to root dir
 DONE- check this in
 - change repo to gitlab
 - finish docs
 - fix top link on pages
 - adjust page priority so the series pages come first

=cut

use 5.14.0;
use warnings;

use Data::Dump qw/dump/;
use Date::Calc qw/Day_of_Week/;

use DBI;
use Template;
use YAML;

my %day_map = (
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    7 => 'Sun',
);

# this is culled from
# grep -r /scripts/serieslists.pl /var/www/bacds.org/public_html/series | grep -v single-event
my %series_to_show = (
    'ceilidh/oakland' => {
        styles =>  [qw/ CEILIDH /],
        venues =>  [qw/ HUM /],
        days =>  [qw/ Fri Thu /],
    },
    'contra/berkeley_wed' => {
        styles =>  [qw/ CONTRA CONTRAWORKSHOP /],
        venues =>  [qw/ STALB CCB STC GNC /],
        days =>  [qw/ Wed /],
    },
    'contra/san_jose' => {
        styles =>  [qw/ CONTRA /],
        venues =>  [qw/ FSJ /],
        days =>  [qw/ Sun /],
    },
    'contra/san_francisco' => {
        styles =>  [qw/ CONTRA /],
        venues =>  [qw/ SF /],
        days =>  [qw/ Fri Sat Sun /],
    },
    'contra/palo_alto' => {
        styles =>  [qw/ CONTRA HAMBO /],
        venues =>  [qw/ FUM SM STA SBE MT SFV LSC WCP FBC SME /],
        days =>  [qw/ Sat Mon Fri Wed Tue Thu Sun /],
    },
    'contra/hayward' => {
        styles =>  [qw/ CONTRA HAMBO /],
        venues =>  [qw/ HVC /],
        days =>  [qw/ Sun /],
    },
    'english/berkeley_wed' => {
        styles =>  [qw/ ENGLISH ENGLISHWORKSHOP /],
        venues =>  [qw/ STC CCB STALB /],
        days =>  [qw/ Wed /],
    },
    'english/peninsula' => {
        styles =>  [qw/ ENGLISH /],
        venues =>  [qw/ ASE FBC MT FHL SME /],
        days =>  [qw/ Tue Wed Thu /],
    },
    'english/san_jose' => {
        styles =>  [qw/ ENGLISH /],
        venues =>  [qw/ COY FSJ /],
        days =>  [qw/ Sun /],
    },
    'english/san_francisco' => {
        styles =>  [qw/ ENGLISH ECDWORKSHOP /],
        venues =>  [qw/ SPC SJP  /],
        days =>  [qw/ Sat Sun /],
    },
    'english/palo_alto' => {
        styles =>  [ 'ENGLISH', 'ECDWORKSHOP', 'SPECIAL/ENGLISH', ],
        venues =>  [qw/ MT SBE /],
        days =>  [qw/ Fri Thu Tue /],
    },
    'english/berkeley_sat' => {
        styles =>  [qw/ ENGLISH /],
        venues =>  [qw/ CCB FBH STC FUO /],
        days =>  [qw/ Sat /],
    },
    'woodshed/atherton' => {
        styles =>  [qw/ WOODSHED /],
        venues => [qw/  HPP /],
        days =>  [qw/ Tue /],
    },
);

sub main {
    generate_sitemap();
}
main();


sub generate_sitemap {

    my $dbh = get_dbh();

    my $urls = get_urls($dbh);

    my $sitemap_xml = make_sitemap($urls);

    #say $sitemap_xml;

}

sub get_dbh {
	my $csv_dir = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
    my $dbh = DBI->connect(qq[DBI:CSV:f_dir=$csv_dir;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\],'','');

    return $dbh;
}

sub get_urls {
    my ($dbh) = @_;

    my $today = $ENV{TEST_TODAY} || `date --iso-8601=date -d '1 week ago'`;

    my @urls;

    my $bacds = "https://www.bacds.org";
    my $base = "$bacds/series";

    push @urls, 
            #"$bacds",
            #"$base/",
            "$base/woodshed/",
            "$base/ceilidh/",
            "$base/contra/",
            "$base/english/",
            "$base/community/";

    my %seen;

    while (my ($urlpart, $series) = each %series_to_show) {
        push @urls,  "$base/$urlpart/";
        my ($query_string) = build_query($dbh, $series);

        my $sth = $dbh->prepare($query_string) or die $dbh->errstr;
        $sth->execute($today) or die $sth->errstr;

        while (my $res = $sth->fetchrow_hashref) {
            my $dow = Day_of_Week(split '-', $res->{startday});
            my $dow_name = $day_map{$dow};
            next unless grep { $dow_name eq $_ } @{$series->{days}};

            my $url = "$base/$urlpart/?single-event=$res->{startday}";

            next if $seen{$url}++; # there are dups in the db

            push @urls,  $url;
        }
    }

    return \@urls;
}


sub build_query {
    my ($dbh, $series) = @_;

    my ($style_ors) = make_orlist($dbh, 'type', @{$series->{styles}});
    my ($venue_ors) = make_orlist($dbh, 'loc', @{$series->{venues}});

    my $query = <<EOL;
        SELECT startday, type, loc FROM schedule
        WHERE startday >= ?
        AND ($style_ors)
        AND ($venue_ors)
EOL
    return $query;
}

sub make_orlist {
    my ($dbh, $what, @vals) = @_;

    my $first_v = shift @vals;
    my $s = "$what LIKE ".$dbh->quote("%$first_v%");
    foreach my $v (@vals) {
        $s .= " OR $what LIKE ".$dbh->quote("%$v%");
    }

    return $s;
}

sub make_sitemap {
    my ($urls) = @_;

    my $template = <<EOL;
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<!-- sitemap was generated by [% generated_by | xml %] at [% now | xml %] -->

[% FOR url IN urls %]
    <url>
        <loc>[% url | xml %]</loc>
        <changefreq>daily</changefreq>
    </url>
[% END %]
</urlset>
EOL

    my $tt = Template->new();

    my $data = {
        urls => $urls,
        generated_by => $0,
        now => scalar localtime,
    };

    my $output = $tt->process(\$template, $data)
        || die $tt->error();

    return $output;
}
