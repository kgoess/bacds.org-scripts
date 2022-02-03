
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 2;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';


test_json();
test_html();


sub test_json {
    $ENV{REQUEST_URI} = '/scripts/dancefinder.pl';
    $ENV{QUERY_STRING} = 'json=TRUE&start=1538005600&end=1540005600_=1540005600';

    my ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    my $decoded = decode_json($stdout);

    my $dance = $decoded->[0];
    my $expected = decode_json(q{
       { "id" : "1",
          "url" : "http://www.bacds.org/series/english/berkeley_wed/",
          "start" : "2018-09-26",
          "end" : "",
          "title" : "ENGLISH at Christ Church Berkeley (formerly Grace North Church) in Berkeley.  Led by Bruce Hamilton.  Music by Open band led by Audrey Knuth, Judy Linsenberg, Patti Cobb.",
          "allDay" : true,
          "backgroundColor" : "darkturquoise",
          "borderColor" : "darkblue",
          "textColor" : "black"
        }
    });
    eq_or_diff $dance, $expected, "dancefinder.pl looks like it's working";
}


sub test_html {
    $ENV{REQUEST_URI} = '/scripts/dancefinder.pl';
    $ENV{QUERY_STRING} = 'json=FALSE&start=1538005600&end=1540005600_=1540005600&venue=CCB';

    my ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $stdout =~ m{<body.*?>(.+?)</body>}ms
        or die "can't find body in stdout:\n$stdout";
    my $body = $1;

    $body =~ m{<h1>(.+?)</h1>}ms
        or die "can't find <h1> in body:\n$body";
    my $h1 = $1;

    like $h1, qr{\QDances At Christ Church Berkeley (formerly Grace North Church) in Berkeley\E},
        "'Dances At ...' line found ok";
}
