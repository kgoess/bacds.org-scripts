
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
    <option value="Nonesuch Country Dance Band">Nonesuch Country Dance Band</option>
    <option value="Open Band">Open Band</option>
    <option value="Pan&rsquo;s Rambles">Pan&rsquo;s Rambles</option>
    <option value="Rodney Miller Band">Rodney Miller Band</option>
    <option value="Shira Kammen, Judy Linsenberg, Bill Skeen, Katherine Heater &mdash; <b>18 dances from 1718 1718 English Ball</b>">Shira Kammen, Judy Linsenberg, Bill Skeen, Katherine Heater &mdash; <b>18 dances from 1718 1718 English Ball</b></option>
    <option value="Toss The Possum">Toss The Possum</option>
    <option value=""></option>
    <option value="& friend">& friend</option>
    <option value="(Daniel Soussan">(Daniel Soussan</option>
    <option value="4&ndash;7 pm &mdash; Contact erik@erikhoffman.com">4&ndash;7 pm &mdash; Contact erik@erikhoffman.com</option>
    <option value="4&ndash;7:15pm&mdash;Zesty!">4&ndash;7:15pm&mdash;Zesty!</option>
    <option value="Anne Bingham Goess">Anne Bingham Goess</option>
    <option value="Audrey Knuth">Audrey Knuth</option>
    <option value="Audrey Knuth, Christopher Jacoby, $14/12/7">Audrey Knuth, Christopher Jacoby, $14/12/7</option>
    <option value="Betsy St. Aubin">Betsy St. Aubin</option>
    <option value="Bill Jensen">Bill Jensen</option>
    <option value="Charlie Hancock">Charlie Hancock</option>
    <option value="Chris Knepper">Chris Knepper</option>
    <option value="Christopher Jacoby">Christopher Jacoby</option>
    <option value="Community Band led by Erik Hoffman">Community Band led by Erik Hoffman</option>
    <option value="Craig Johnson">Craig Johnson</option>
    <option value="Dance 2:30">Dance 2:30</option>
    <option value="Dance 3&ndash;6pm">Dance 3&ndash;6pm</option>
    <option value="Daniel Soussan">Daniel Soussan</option>
    <option value="Daniel Steinberg">Daniel Steinberg</option>
    <option value="Derry Akin">Derry Akin</option>
    <option value="Erik Hoffman">Erik Hoffman</option>
    <option value="Jess Newman">Jess Newman</option>
    <option value="Judy Linsenberg">Judy Linsenberg</option>
    <option value="Laura Zisette">Laura Zisette</option>
    <option value="Mark Daly">Mark Daly</option>
    <option value="Mark Price">Mark Price</option>
    <option value="Mark Price) &mdash;Intro at 2:30">Mark Price) &mdash;Intro at 2:30</option>
    <option value="Mary Tabor">Mary Tabor</option>
    <option value="Mary Tabor) Robin Lockner">Mary Tabor) Robin Lockner</option>
    <option value="Nonesuch Country Dance Band">Nonesuch Country Dance Band</option>
    <option value="Open band led by Audrey Knuth">Open band led by Audrey Knuth</option>
    <option value="Open band led by Divertimento&mdash;Dances for the BAERS Frankenstein Ball tomorrow night">Open band led by Divertimento&mdash;Dances for the BAERS Frankenstein Ball tomorrow night</option>
    <option value="Pan&rsquo;s Rambles (Derry Akin">Pan&rsquo;s Rambles (Derry Akin</option>
    <option value="Patti Cobb">Patti Cobb</option>
    <option value="Paul Kotapish">Paul Kotapish</option>
    <option value="Phoenix Rising (William Allen">Phoenix Rising (William Allen</option>
    <option value="Rob Powell">Rob Powell</option>
    <option value="Rob Zisette">Rob Zisette</option>
    <option value="Robin Lockner)  &mdash;season opening party! Workshop 2:10">Robin Lockner)  &mdash;season opening party! Workshop 2:10</option>
    <option value="Robin Lockner, Bill Jensen">Robin Lockner, Bill Jensen</option>
    <option value="Rodney Miller">Rodney Miller</option>
    <option value="Rodney Miller Band">Rodney Miller Band</option>
    <option value="Tom Lindemuth&mdash;for experienced dancers">Tom Lindemuth&mdash;for experienced dancers</option>
    <option value="William Allen">William Allen</option>
    <option value="about set list">about set list</option>
    <option value="etc; dancers give input">etc; dancers give input</option>
    <option value="free for everyone.  Callers try out new material">free for everyone.  Callers try out new material</option>
    <option value="maybe you? - A peek backstage">maybe you? - A peek backstage</option>
    <option value="music">music</option>
    <option value="now sold out">now sold out</option>
    <option value="rehearsals">rehearsals</option>
    <option value="schedule not yet published">schedule not yet published</option>
    <option value="teaching techniques">teaching techniques</option>
    <option value="the test zoom band">the test zoom band</option>
    <option value="things get better.  Join us!">things get better.  Join us!</option>
</select>
EOL

eq_or_diff $stdout, $expected, "with no args";

