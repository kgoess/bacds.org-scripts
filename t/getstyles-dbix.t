
use 5.16.0;
use warnings;

use Capture::Tiny qw/capture/;
use FindBin qw/$Bin/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 4;

# use the git checkout, not the installed version
use lib "$Bin/../../dance-scheduler/lib";

use bacds::Scheduler::Util::Test qw/setup_test_db/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';
$ENV{TEST_NOW} = DateTime
    ->new(year => 2018, month => 9, day => 6)
    ->epoch;  # bacds::Scheduler::Util::Time's get_now

$ENV{COOKIE} = 'DBIX_TEST=1';

my $expected;
my ($stdout, $stderr, $exit);

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
my $venue_ccb = $dbh->resultset('Venue')->new({
    vkey => 'CCB',
    city => 'Berkeley',
    hall_name => q{Christ Church Berkeley <formerly Grace North Church>},
});
$venue_ccb->insert;

my $style_english = $dbh->resultset('Style')->new({
    name => 'ENGLISH',
});
$style_english->insert;
my $style_contra = $dbh->resultset('Style')->new({
    name => 'CONTRA',
});
$style_contra->insert;
my $style_regency = $dbh->resultset('Style')->new({
    name => 'REGENCY',
});
$style_regency->insert;
my $style_special = $dbh->resultset('Style')->new({
    name => 'SPECIAL',
});
$style_special->insert;
my $style_waltz = $dbh->resultset('Style')->new({
    name => 'WALTZ',
});
$style_waltz->insert;

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

# this Event3 is a month later and has two styles
my $Event3 = $dbh->resultset('Event')->new({
    name => 'test event 3',
    synthetic_name => 'test event 3 synthname',
    start_date => get_now->add(days => 30)->ymd('-'),
    start_time => '20:00',
});
$Event3->insert;
$Event3->add_to_venues($venue_ccb, {ordering => 1});
$Event3->add_to_styles($style_english, {ordering => 1});
$Event3->add_to_styles($style_regency, {ordering => 2});

#
# with no args
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
        <option value="CONTRA">CONTRA</option>
        <option value="ENGLISH">ENGLISH</option>
        <option value="REGENCY">REGENCY</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";


#
# style=ENGLISH
#
$ENV{QUERY_STRING} = 'style=ENGLISH';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
        <option value="ENGLISH">ENGLISH</option>
</select>
EOL

eq_or_diff $stdout, $expected, "style=ENGLISH";


#
# numdays=1 (is a boolean)
#
$ENV{QUERY_STRING} = 'numdays=1';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
        <option value="CONTRA">CONTRA</option>
        <option value="ENGLISH">ENGLISH</option>
</select>
EOL

eq_or_diff $stdout, $expected, "numdays=1";


#
# venue=CCB
#
$ENV{QUERY_STRING} = 'venue=CCB';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
        <option value="ENGLISH">ENGLISH</option>
        <option value="REGENCY">REGENCY</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

# skipping the "include a camp" test case from t/getstyles.t
# which might have been testing some of the
# bacds::Model::Event->load_all args?
