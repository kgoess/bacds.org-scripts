
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use FindBin qw/$Bin/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 1;

# use the git checkout, not the installed version
use lib "$Bin/../../dance-scheduler/lib";

use bacds::Scheduler::Util::Test qw/setup_test_db/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

my $expected;
my ($stdout, $stderr, $exit);

$ENV{COOKIE} = 'DBIX_TEST=1';

setup_test_db;

my $dbh = get_dbh;

my $Caller1 = $dbh->resultset('Caller')->new({
    name => q{D'Artagnan the Bold},
});
$Caller1->insert;
my $Caller2 = $dbh->resultset('Caller')->new({
    name => q{Duane "The Rock" Johnson},
});
$Caller2->insert;
my $Event1 = $dbh->resultset('Event')->new({
    name => 'test event 1',
    synthetic_name => 'test event 1 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event1->insert;
$Event1->add_to_callers($Caller1, {ordering => 1});
my $Event2 = $dbh->resultset('Event')->new({
    name => 'test event 2',
    synthetic_name => 'test event 2 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event2->insert;
$Event2->add_to_callers($Caller2, {ordering => 1});

#
# getleaders.pl doesn't look at QUERY_STRING so only the one test
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/getleaders.pl';
};
die "getleaders.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="caller">
    <option value="">ALL LEADERS</option>
        <option value="D'Artagnan the Bold">D'Artagnan the Bold</option>
        <option value="Duane &quot;The Rock&quot; Johnson">Duane &quot;The Rock&quot; Johnson</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

