
use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use Data::Dump qw/dump/;
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use JSON qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 25;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';


test_json();
test_html();
test_args();


sub test_json {
    $ENV{REQUEST_URI} = '/scripts/dancefinder.pl';
    $ENV{QUERY_STRING} = 'json=TRUE&start=1538005600&end=1540005600';

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
    $ENV{QUERY_STRING} = 'json=FALSE&start=1538005600&end=1540005600&venue=CCB';

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

# more detailed testing
sub test_args {
    $ENV{REQUEST_URI} = '/scripts/dancefinder.pl';
    local $ENV{TEST_TODAY} = '2018-09-26';

    my ($stdout, $stderr, $exit, $decoded);
    
    #
    # start and end days
    #
    $ENV{QUERY_STRING} = 'json=TRUE&start=1538005600&end=1538092000';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 2, 'two things in results' or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;
    like $decoded->[1]{title}, qr/WALTZ at Christ Church Berkeley/,
        'second one is waltz' or dump $decoded;

    #
    # numdays=1, just today
    #
    $ENV{QUERY_STRING} = 'json=TRUE&numdays=1';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 2, 'two things in results for numdays=1' or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;
    like $decoded->[1]{title}, qr/WALTZ at Christ Church Berkeley/,
        'second one is waltz' or dump $decoded;

    #
    # numdays=4, picks up a third dance
    #
    $ENV{QUERY_STRING} = 'json=TRUE&numdays=4';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 3, 'three things in resulta for numdays=4s' or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;
    like $decoded->[1]{title}, qr/WALTZ at Christ Church Berkeley/,
        'second one is waltz' or dump $decoded;
    like $decoded->[2]{title}, qr/CONTRA at First United Methodist/,
        'third one is contra' or dump $decoded;

    #
    # startdate and enddate, pick up the same three
    #
    $ENV{QUERY_STRING} = 'json=TRUE&start=1538005600&end=1538351200';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 3, 'three things in results for date range' or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;
    like $decoded->[1]{title}, qr/WALTZ at Christ Church Berkeley/,
        'second one is waltz' or dump $decoded;
    like $decoded->[2]{title}, qr/CONTRA at First United Methodist/,
        'third one is contra' or dump $decoded;


    #
    # numdays=4, venue=CCB
    #
    $ENV{QUERY_STRING} = 'json=TRUE&numdays=4&venue=CCB';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 2, 'only two of them are at CCB' or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;
    like $decoded->[1]{title}, qr/WALTZ at Christ Church Berkeley/,
        'second one is waltz' or dump $decoded;

    #
    # numdays=4, caller=Bruce Hamilton
    #
    $ENV{QUERY_STRING} = 'json=TRUE&numdays=4&caller=Bruce Hamilton';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 1, "only one of them is Bruce's" or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;

    #
    # numdays=4, style=CONTRA
    #
    $ENV{QUERY_STRING} = 'json=TRUE&numdays=4&style=CONTRA';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 1, "only one of them is CONTRA" or dump $decoded;
    
    like $decoded->[0]{title}, qr/CONTRA at First United Methodist Church/;
         'first one is english' or dump $decoded;

    #
    # numdays=4, muso=Nonesuch
    #
    $ENV{QUERY_STRING} = 'json=TRUE&numdays=4&muso=Open band';
    ($stdout, $stderr, $exit) = capture {
        do 'scripts/dancefinder.pl';
    };
    die "dancefinder.pl died: $@ $stderr" if !$exit;
    note $stderr if $stderr;

    $decoded = decode_json($stdout);

    is @$decoded, 1, "only one of them is Open band" or dump $decoded;
    
    like $decoded->[0]{title}, qr/ENGLISH at Christ Church Berkeley/,
         'first one is english' or dump $decoded;
}
