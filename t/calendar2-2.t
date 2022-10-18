
# more detailed tests of calendar2.pl

use 5.16.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use Test::More tests => 6;
use Test::Differences qw/eq_or_diff/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

$ENV{REQUEST_URI} = '/calendars/2018/09/index.pl';


my ($stdout, $stderr, $exit) = capture {
	do 'cgi-bin/calendar2.pl';
};
die "calendar2.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;


my @res;

@res = parse_url_params('/calendars/2022/12/index.pl');
eq_or_diff \@res, [2022, 12, 2022, 12, 'schedule'];

@res = parse_url_params('/calendars/2017/07/index.pl');
eq_or_diff \@res, [2017, 7, 2017, 7, 'schedule2017'];

# "current" fetches the params from TEST_TODAY
@res = parse_url_params('/calendars/current/index.pl');
# note the spurious leading "0" in the month, will fix
eq_or_diff \@res, [2018, '09', 2018, '09', 'schedule'];


# missing "/calendars/" just fetches today
@res = parse_url_params('/argleblargle/current/index.pl');
eq_or_diff \@res, [2018, '09', 2018, '09', 'schedule'];
# note the spurious leading "0" in the month, will fix
eq_or_diff \@res, [2018, '09', 2018, '09', 'schedule'];


# sql injection demonstration
@res = parse_url_params(q{/calendars/"; drop table 'schedule';/index.pl});
is $res[0], q{"; drop table 'schedule';};
