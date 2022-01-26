
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 1;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

my ($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $stderr" if !$exit;
note $stderr if $stderr;

like $stdout, qr{<option value="CONTRA">CONTRA</option>},
    "looks like getstyles.pl is working";
