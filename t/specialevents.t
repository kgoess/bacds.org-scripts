
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
    do 'scripts/specialevents.pl';
};
die "specialevents.pl died: $@ $stderr $stdout" if !$exit;
note $stderr if $stderr;

my $expected = <<EOL;
<p class="listing">
Saturday, November 17, 2018:  
<strong>ENGLISH/SPECIAL</strong> at Hillside Club in Berkeley.  
Kalia Kliban, Sharon Green, Mary Luckhardt with music by Shira Kammen, Judy Linsenberg, Bill Skeen, Katherine Heater &mdash; <b>18 dances from 1718 1718 English Ball</b> (now sold out) <a href="/events/1718">More Info</a>
</p>
<p class="listing">
Friday, November 30&ndash;Saturday, December 01, 2018:  
<strong>CONTRA/CAMP/SPECIAL</strong>: Monte Toyon Camp, CAMP<em>Test Camp That Crosses Month Boundary</em>.
Test Caller with music by Test Band</p>
EOL

eq_or_diff $stdout, $expected,
    "looks like specialevents.pl is working";
