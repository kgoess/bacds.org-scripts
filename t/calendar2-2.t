
# more detailed tests of calendar2.pl

use 5.16.0;
use warnings;

use Capture::Tiny qw/capture capture_stdout/;
use Data::Dump qw/dump/;
use File::Basename qw/basename/;
use List::MoreUtils qw/any/;
use Test::More tests => 18;
use Test::Differences qw/eq_or_diff/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

$ENV{REQUEST_URI} = '/calendars/2018/09/index.pl';


my ($stdout, $stderr, $exit) = capture {
	do 'cgi-bin/calendar2.pl';
};
die "calendar2.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;


test_parse_url_params();
test_db_sched_lookup();


sub test_parse_url_params {

    my @res;

    @res = parse_url_params('/calendars/2022/12/index.pl');
    eq_or_diff \@res, [2022, 12, 'schedule'];

    @res = parse_url_params('/calendars/2017/07/index.pl');
    eq_or_diff \@res, [2017, 7, 'schedule2017'];

    # "current" fetches the params from TEST_TODAY
    @res = parse_url_params('/calendars/current/index.pl');
    eq_or_diff \@res, [2018, 9, 'schedule'];


    # missing "/calendars/" just fetches today
    @res = parse_url_params('/argleblargle/current/index.pl');
    eq_or_diff \@res, [2018, 9, 'schedule'];


    # sql injection demonstration
    @res = parse_url_params(q{/calendars/"; drop table 'schedule';/index.pl});
    is $res[0], '2018';

    # silly long param sanitization
    @res = parse_url_params('/calendars/2017777777777/07777777777/index.pl');
    eq_or_diff \@res, [2017, 7, 'schedule2017'];
}

sub test_db_sched_lookup {
    my ($res, $stdout);

    #
    # try a regular month, no camps
    #
    $res = db_sched_lookup('2018', '02', 'schedule2018');

    is @$res, 22;
    is $res->[0], '2018-02-02||ENGLISH|MT|Alisa Dodson (2018 Playford Ball Ogre)|Nonesuch Country Dance Band (Daniel Soussan, Mark Daly, Mary Tabor) with Robin Lockner, Paul Kostka, William Allen';
    is $res->[21], '2018-02-28||ENGLISH|CCB|Kalia Kliban|Sister Haggis (Eileen Nicholson Kolfass, Jane Knoeck) [both NY]&mdash;<b><i>NOT an open band</i></b>';

    #
    # august has a bunch of camps, but none of them cross the month boundary
    #
    $res = db_sched_lookup('2018', '08', 'schedule2018');
    is @$res, 26;

    #
    # we made a test camp that cross the November/December boundary, should
    # show up in each
    #
    $res = db_sched_lookup('2018', '11', 'schedule2018');
    ok any { /Test Camp That Crosses Month Boundary/ } @$res;
    $stdout = capture_stdout { print_schedule('2018', '11', $res) };
    $stdout =~ s/<td/\n<td/g; # easier to read failures
    $stdout =~ s/&nbsp;/ /g;
    like $stdout, qr{<a name="2018-11-03"></a>November 03</td>};
    like $stdout, qr/November 30 to December 01/;
    like $stdout,  qr/Test Camp That Crosses Month Boundary/;

    $res = db_sched_lookup('2018', '12', 'schedule2018');
    ok any { /Test Camp That Crosses Month Boundary/ } @$res;
    $stdout = capture_stdout { print_schedule('2018', '12', $res) };
    $stdout =~ s/<td/\n<td/g; # easier to read failures
    $stdout =~ s/&nbsp;/ /g;
    like $stdout, qr{<a name="2018-12-04"></a>December 04</td>};
    like $stdout, qr/November 30 to December 01/;
    like $stdout,  qr/Test Camp That Crosses Month Boundary/;
}
