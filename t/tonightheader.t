
# all the logic in tonightheader is just for printing either a) "Today's Dance"
# singular, b) "Today's Dances" plural, or c) no header because no dances today

use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 3;

$ENV{TEST_CSV_DIR} = 't/data/';

my ($stdout, $stderr, $exit);

#
# there's one dance on the third
#
$ENV{TEST_TODAY} = '2018-01-03';

($stdout, $stderr, $exit) = capture {
    do 'scripts/tonightheader.pl';
};
die "tonightheader.pl died: $stderr" if !$exit;
note $stderr if $stderr;

like $stdout, qr{<h2>Today's Dance!</h2>},
    "one dance on the third";


#
# there are no dances on the fourth
#
$ENV{TEST_TODAY} = '2018-01-04';

($stdout, $stderr, $exit) = capture {
    do 'scripts/tonightheader.pl';
};
die "tonightheader.pl died: $stderr" if !$exit;
note $stderr if $stderr;

unlike $stdout, qr{<h2>Today's Dance},
    "no dances on the fourth";


#
# and *two* dances on the 27th
#
$ENV{TEST_TODAY} = '2018-01-27';

($stdout, $stderr, $exit) = capture {
    do 'scripts/tonightheader.pl';
};
die "tonightheader.pl died: $stderr" if !$exit;
note $stderr if $stderr;

like $stdout, qr{<h2>Today's Dances!</h2>},
    "three dances on the 27th";
