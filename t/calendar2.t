
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 2;
use Test::Output qw/stdout_like stdout_is/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';

$ENV{REQUEST_URI} = '/calendars/2018/09/index.pl';


my ($stdout, $stderr, $exit) = capture {
	do 'cgi-bin/calendar2.pl';
};
die $stderr if !$exit;


my $result = reformat_result($stdout);

# check one of the listings
my $expected = q{<td class="callisting">
<a name="2018-09-01"></a>September&nbsp;01</td>
<td class="callisting">CONTRAWORKSHOP</td>
<td class="callisting">SF</td>
<td class="callisting">Alexandra Deis-Lauby[NYC]</td>
<td class="callisting">Special Flourish workshop, 6:30-7:30, $5  Be prepared to try both roles.  Be there early enough to be ready to go at  6:30.</td>
};
my $index = index $result, $expected;
ok $index > 0, 'found "Special Fourish workshop" in output'
	or handle_fail($result, $expected);


# check the calendar part
$expected = q{
<td class="calendar"><a href="#2018-09-05">5</a></td>
<td class="calendar"><div class="tonight">6</div></td>
<td class="calendar"><a href="#2018-09-07">7</a></td>
};
$index = index $result, $expected;
ok $index > 0, 'calendar part looks right'
	or handle_fail($result, $expected);



sub reformat_result {

	my ($tempfh, $tempfile) = tempfile();
	open my $formatter, '|-', "/usr/bin/xmllint --format --html --output $tempfile - 2>/dev/null"
		or die "can't run xmllint $!";
	print $formatter $stdout;
	close $formatter;
	my $result = do { local $/; <$tempfh> };

	return $result;
}

sub handle_fail {
	my $basename = basename $0;
	my $fh;
	open $fh, '>', "$basename.expected" or die "can't write to '$basename.expected' $!";
	print $fh $expected;
	open $fh, '>', "$basename.got" or die "can't write to '$basename.got' $!";
	print $fh $result;
	BAIL_OUT("see $basename.got versus $basename.expected");
}
	

