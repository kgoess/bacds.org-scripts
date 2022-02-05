
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 5;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

my $expected;
my ($stdout, $stderr, $exit);

#
# with no args
#
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
    <option value="CONTRA">CONTRA</option>
    <option value="ENGLISH">ENGLISH</option>
    <option value="ENGLISH/REGENCY">ENGLISH/REGENCY</option>
    <option value="ENGLISH/WORKSHOP">ENGLISH/WORKSHOP</option>
    <option value="ONLINE ENGLISH DANCE">ONLINE ENGLISH DANCE</option>
    <option value="SPECIAL">SPECIAL</option>
    <option value="WALTZ">WALTZ</option>
    <option value="WOODSHED">WOODSHED</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";


#
# style=ENGLISH
#
$ENV{QUERY_STRING} = 'style=ENGLISH';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
    <option value="ENGLISH">ENGLISH</option>
    <option value="ENGLISH/REGENCY">ENGLISH/REGENCY</option>
    <option value="ENGLISH/WORKSHOP">ENGLISH/WORKSHOP</option>
    <option value="ONLINE ENGLISH DANCE">ONLINE ENGLISH DANCE</option>
    <option value="SPECIAL">SPECIAL</option>
</select>
EOL

eq_or_diff $stdout, $expected, "style=ENGLISH";




#
# numdays=1 (is a boolean)
#
$ENV{QUERY_STRING} = 'numdays=1';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
    <option value="CONTRA">CONTRA</option>
    <option value="ENGLISH">ENGLISH</option>
    <option value="ENGLISH/WORKSHOP">ENGLISH/WORKSHOP</option>
    <option value="WOODSHED">WOODSHED</option>
</select>
EOL

eq_or_diff $stdout, $expected, "style=ENGLISH";


#
# venue=CCB
#
$ENV{QUERY_STRING} = 'venue=CCB';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
    <option value="CONTRA">CONTRA</option>
    <option value="ENGLISH">ENGLISH</option>
    <option value="ENGLISH/WORKSHOP">ENGLISH/WORKSHOP</option>
    <option value="WALTZ">WALTZ</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";



#
# include a camp
#
$ENV{TEST_TODAY} = '2018-08-10';
$ENV{QUERY_STRING} = 'numdays=1';
($stdout, $stderr, $exit) = capture {
    do 'scripts/getstyles.pl';
};
die "getstyles.pl died: $@ $stderr" if !$exit;
note $stderr if $stderr;

$expected = <<EOL;
<select name="style">
    <option value="">ALL STYLES</option>
    <option value="CAMP">CAMP</option>
    <option value="CONTRA">CONTRA</option>
    <option value="ENG/REG">ENG/REG</option>
    <option value="ENGLISH">ENGLISH</option>
    <option value="SPECIAL">SPECIAL</option>
    <option value="WOODSHED">WOODSHED</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";
