
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use Data::Dump qw/dump/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 4;

use bacds::Scheduler::Util::Test qw/setup_test_db/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';
$ENV{TEST_NOW} = DateTime
    ->new(year => 2018, month => 9, day => 6)
    ->epoch;  # bacds::Scheduler::Util::Time's get_now

my $expected;
my ($stdout, $stderr, $exit);

$ENV{COOKIE} = 'DBIX_TEST=1';

setup_test_db;

my $dbh = get_dbh;


my $venue_alb = $dbh->resultset('Venue')->new({
    vkey => 'ALB',
    city => 'Albany',
    hall_name => q{Albany Veteran's Memorial Building},
});
$venue_alb->insert;
my $venue_kdt = $dbh->resultset('Venue')->new({
    vkey => 'KDT',
    city => 'Oakland',
    hall_name => q{Kids ’N Dance ’N Theater},
});
$venue_kdt->insert;
my $venue_gnc = $dbh->resultset('Venue')->new({
    vkey => 'CCB',
    city => 'Berkeley',
    hall_name => q{Christ Church Berkeley <formerly Grace North Church>},
});
$venue_gnc->insert;

my $style_english = $dbh->resultset('Style')->new({
    name => 'ENGLISH',
});
$style_english->insert;
my $style_contra = $dbh->resultset('Style')->new({
    name => 'CONTRA',
});
$style_contra->insert;


my $Event1 = $dbh->resultset('Event')->new({
    name => 'test event 1',
    synthetic_name => 'test event 1 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event1->insert;
$Event1->add_to_venues($venue_alb, {ordering => 1});
$Event1->add_to_styles($style_english, {ordering => 1});

my $Event2 = $dbh->resultset('Event')->new({
    name => 'test event 2',
    synthetic_name => 'test event 2 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event2->insert;
$Event2->add_to_venues($venue_kdt, {ordering => 1});
$Event2->add_to_styles($style_contra, {ordering => 1});

my $Event3 = $dbh->resultset('Event')->new({
    name => 'test event 3',
    synthetic_name => 'test event 3 synthname',
    start_date => get_now->add(days => 30)->ymd('-'),
    start_time => '20:00',
});
$Event3->insert;
$Event3->add_to_venues($venue_gnc, {ordering => 1});
$Event3->add_to_styles($style_english, {ordering => 1});
$Event3->add_to_styles($style_contra, {ordering => 2});

#
# with no args
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
        <option value="ALB">Albany -- Albany Veteran's Memorial Building</option>
        <option value="CCB">Berkeley -- Christ Church Berkeley &lt;formerly Grace North Church&gt;</option>
        <option value="KDT">Oakland -- Kids \xe2\x80\x99N Dance \xe2\x80\x99N Theater</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

#
# style=ENGLISH
#
$ENV{QUERY_STRING} = 'style=ENGLISH';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
        <option value="ALB">Albany -- Albany Veteran's Memorial Building</option>
        <option value="CCB">Berkeley -- Christ Church Berkeley &lt;formerly Grace North Church&gt;</option>
</select>
EOL

eq_or_diff $stdout, $expected, "style=ENGLISH";


#
# numdays=1 (is a boolean)
#
$ENV{QUERY_STRING} = 'numdays=1';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
        <option value="ALB">Albany -- Albany Veteran's Memorial Building</option>
        <option value="KDT">Oakland -- Kids \xe2\x80\x99N Dance \xe2\x80\x99N Theater</option>
</select>
EOL

eq_or_diff $stdout, $expected, "numdays=1";


#
# venue=CCB
#
$ENV{QUERY_STRING} = 'venue=CCB';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
        <option value="CCB">Berkeley -- Christ Church Berkeley &lt;formerly Grace North Church&gt;</option>
</select>
EOL

eq_or_diff $stdout, $expected, "venue=CCB";

