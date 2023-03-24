
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

my $expected;
my ($stdout, $stderr, $exit);

$ENV{COOKIE} = 'DBIX_TEST=1';

setup_test_db();

my $dbh = get_dbh();

my $alice = $dbh->resultset('Talent')->new({
    name => 'alice',
});
$alice->insert;
my $bob = $dbh->resultset('Talent')->new({
    name => 'bob',
});
$bob->insert;
my $chuck = $dbh->resultset('Talent')->new({
    name => 'chuck',
});
$chuck->insert;
my $dave = $dbh->resultset('Talent')->new({
    name => 'dave',
});
$dave->insert;
my $eve = $dbh->resultset('Talent')->new({
    name => 'eve',
});
$eve->insert;
my $felicity = $dbh->resultset('Talent')->new({
    name => 'felicity',
});
$felicity->insert;
my $grace = $dbh->resultset('Talent')->new({
    name => 'grace',
});
$grace->insert;
my $honor = $dbh->resultset('Talent')->new({
    name => 'honor',
});
$honor->insert;

my $def_band = $dbh->resultset('Band')->new({
    name => 'def band',
});
$def_band->insert;
my $i = 1;
$def_band->add_to_talents($dave, {ordering => $i++});
$def_band->add_to_talents($eve, {ordering => $i++});
$def_band->add_to_talents($felicity, {ordering => $i++});

my $other_band = $dbh->resultset('Band')->new({
    name => 'other band',
});
$other_band->insert;


my $Event1 = $dbh->resultset('Event')->new({
    name => 'test event 1',
    synthetic_name => 'test event 1 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event1->insert;
# event1 has two bands and one extra muso
$Event1->add_to_bands($def_band, {ordering => $i++});
$Event1->add_to_bands($other_band, {ordering => $i++});
$Event1->add_to_talent($alice, {ordering => $i++});

my $Event2 = $dbh->resultset('Event')->new({
    name => 'test event 2',
    synthetic_name => 'test event 2 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event2->insert;
# event2 has no bands, only individual musos
$Event2->add_to_talent($bob, {ordering => $i++});
$Event2->add_to_talent($chuck, {ordering => $i++});
$Event2->add_to_talent($grace, {ordering => $i++});
$Event2->add_to_talent($honor, {ordering => $i++});

#
# This script ignores QUERY_STRING so only the one test
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/getmusos.pl';
};
die "getmusos.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<'EOL';
<select name="muso">
    <option value="">ALL BANDS AND MUSICIANS</option>
        <option value="def band">def band</option>
        <option value="other band">other band</option>
    <option value=""></option>
        <option value="alice">alice</option>
        <option value="bob">bob</option>
        <option value="chuck">chuck</option>
        <option value="dave">dave</option>
        <option value="eve">eve</option>
        <option value="felicity">felicity</option>
        <option value="grace">grace</option>
        <option value="honor">honor</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

