
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

my $expected;
my ($stdout, $stderr, $exit);

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
    <option value="6:45&ndash;7:30pm">6:45&ndash;7:30pm</option>
    <option value="Alan Winston">Alan Winston</option>
    <option value="Alexandra Deis-Lauby">Alexandra Deis-Lauby</option>
    <option value="Bruce Hamilton">Bruce Hamilton</option>
    <option value="Bruce Herbold">Bruce Herbold</option>
    <option value="Erik Hoffman">Erik Hoffman</option>
    <option value="FREE! (donations gladly accepted)">FREE! (donations gladly accepted)</option>
    <option value="Kalia Kliban">Kalia Kliban</option>
    <option value="Kelsey Hartman">Kelsey Hartman</option>
    <option value="Lynn Ackerson">Lynn Ackerson</option>
    <option value="Mary Luckhardt">Mary Luckhardt</option>
    <option value="Mavis McGaugh">Mavis McGaugh</option>
    <option value="Patti Cobb">Patti Cobb</option>
    <option value="Sharon Green">Sharon Green</option>
    <option value="Sharon Green ">Sharon Green </option>
    <option value="Steve White">Steve White</option>
    <option value="Waltz Away Your Worries (free waltzing">Waltz Away Your Worries (free waltzing</option>
    <option value="Yoyo Zhou">Yoyo Zhou</option>
    <option value="maybe you?">maybe you?</option>
    <option value="no teaching) Audrey Knuth">no teaching) Audrey Knuth</option>
    <option value="tba">tba</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

