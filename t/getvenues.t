
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use Data::Dump qw/dump/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 4;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

my $expected;
my ($stdout, $stderr, $exit);

#
# with no args
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
    <option value="ASE">Palo Alto -- All Saints Episcopal Church</option>
    <option value="CCB">Berkeley -- Christ Church Berkeley (formerly Grace North Church)</option>
    <option value="FSJ">San Jose -- First Unitarian Church of San Jose</option>
    <option value="FUM">Palo Alto -- First United Methodist Church of Palo Alto</option>
    <option value="HC">Berkeley -- Hillside Club</option>
    <option value="HPP">Atherton -- Carriage House at Holbrook-Palmer Park</option>
    <option value="HVC">Hayward -- Hill and Valley Club - 1808 B Street (at Linden)</option>
    <option value="MT">Palo Alto -- Palo Alto Masonic Temple</option>
    <option value="ONLINE">the cloud -- wherever</option>
    <option value="SF">San Francisco -- St. Paul's Presbyterian Church</option>
    <option value="SJP">San Francisco -- St. John's Presbyterian Church</option>
    <option value="SME">Palo Alto -- St. Mark's Episcopal Church</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

#
# style=ENGLISH
#
$ENV{QUERY_STRING} = 'style=ENGLISH';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
    <option value="ASE">Palo Alto -- All Saints Episcopal Church</option>
    <option value="CCB">Berkeley -- Christ Church Berkeley (formerly Grace North Church)</option>
    <option value="FSJ">San Jose -- First Unitarian Church of San Jose</option>
    <option value="HC">Berkeley -- Hillside Club</option>
    <option value="MT">Palo Alto -- Palo Alto Masonic Temple</option>
    <option value="ONLINE">the cloud -- wherever</option>
    <option value="SJP">San Francisco -- St. John's Presbyterian Church</option>
    <option value="SME">Palo Alto -- St. Mark's Episcopal Church</option>
</select>
EOL

eq_or_diff $stdout, $expected, "style=ENGLISH";


#
# numdays=1 (is a boolean)
#
$ENV{QUERY_STRING} = 'numdays=1';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
    <option value="CCB">Berkeley -- Christ Church Berkeley (formerly Grace North Church)</option>
    <option value="FSJ">San Jose -- First Unitarian Church of San Jose</option>
    <option value="FUM">Palo Alto -- First United Methodist Church of Palo Alto</option>
    <option value="HPP">Atherton -- Carriage House at Holbrook-Palmer Park</option>
    <option value="MT">Palo Alto -- Palo Alto Masonic Temple</option>
    <option value="SJP">San Francisco -- St. John's Presbyterian Church</option>
</select>
EOL

eq_or_diff $stdout, $expected, "style=ENGLISH";


#
# venue=CCB
#
$ENV{QUERY_STRING} = 'venue=CCB';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getvenues.pl';
};
die "getvenues.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="venue">
    <option value="">ALL LOCATIONS</option>
    <option value="CCB">Berkeley -- Christ Church Berkeley (formerly Grace North Church)</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

