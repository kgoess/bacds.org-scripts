
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 2;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-12-30';

my ($stdout, $stderr, $exit);


#
# zoomevents.pl
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/zoomevents.pl';
};
die "zoomevents.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

like $stdout, qr{Sharon Green.*with music by the test zoom band}s,
    "looks like zoomevents.pl is working";


#
# zoomevents2.pl
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/zoomevents2.pl';
};
die "zoomevents2.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

like $stdout, qr{Sharon Green.*with music by the test zoom band}s,
    "looks like zoomevents2.pl is working";
