# some basic tests for serieslists.pl as I change it around


use 5.14.0;
use warnings;

use Capture::Tiny qw/capture/;
use Data::Dump qw/dump/;
use JSON qw/from_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 26;
use Test::Output qw/stdout_like stdout_is/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_TODAY} = '2018-09-06';
$ENV{HTTP_HOST} = 'www.bacds.org';
$ENV{DOCUMENT_URI} = '/offer-url';
$ENV{PERL5LIB} = join ':', @INC; # so that system "..." works

my ($stdout, $stderr, $exit);

$ENV{QUERY_STRING} = 'styles=CONTRA,HAMBO&venues=HVC&day=Sun';
($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
like $stdout, qr{
    2018-09-23-CONTRA.*
    Sunday,.September.23.*
    Hill.and.Valley.Club.-.1808.B.Street.*
    Caller:..Yoyo.Zhou.*
    2018-09-30-CONTRA.*
    Sunday,.September.30.*
    Caller:..Lynn.Ackerson.*
    Band:..Rodney.Miller.Band,.4&ndash;7:15pm&mdash;Zesty!.*
    2018-10-28-CONTRA.*
    Band:..schedule.not.yet.published.*
    2018-11-25-CONTRA.*
    2018-12-23-CONTRA.*
    2018-12-30-CONTRA.*
}msx, 'HVC contra looks ok';


# **********
# multiple venues
$ENV{QUERY_STRING} = 'venues=COY,FSJ&day=Sun&style=ENGLISH';
($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
like $stdout, qr{
2018-09-09-ENGLISH.*
Sunday,.September.9.*
First.Unitarian.Church.of.San.Jose,.160.N.3rd.St.*
Caller:..Alexandra.Deis-Lauby.\[NYC\].*
Band:..Phoenix.Rising.\(William.Allen,.Mary.Tabor,.Robin.Lockner\)..&mdash;season.opening.party!.Workshop.2:10,.Dance.2:30.*
2018-10-14-ENGLISH.*
Sunday,.October.14.*
Caller:..tba.*
Band:..schedule.not.yet.published.*
2018-11-11-ENGLISH.*
2018-12-09-ENGLISH.*
}msx, 'COY,FSJ english looks ok';


# ***************
# multiple venues, multiple styles
$ENV{QUERY_STRING} = 'styles=ENGLISH,ECDWORKSHOP&venues=STC,CCB,STALB&day=Wed';
($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
say STDERR $stderr if $stderr;
if ($exit) {
    die $stdout.$stderr;
}
like $stdout, qr{
    <!--.TYPE.=.ENGLISH/WORKSHOP.-->.*
    <div.class="workshop">.*
    <a.name="2018-09-12-ENGLISH/WORKSHOP"></a>.*
    Christ.Church.Berkeley..formerly.Grace.North.Church.,.2138.Cedar.Street,.Berkeley.*
    Caller:..Sharon.Green.*
    Band:..Toss.The.Possum.\(Laura.Zisette.\[UT\],.Rob.Zisette.\[VA\]\).with.Audrey.Knuth,.Christopher.Jacoby,.\$14/12/7.*
    2018-09-26-ENGLISH.*
    Caller:..Bruce.Hamilton.*
    Band:..Open.band.led.by.Audrey.Knuth,.Judy.Linsenberg,.Patti.Cobb.*
    2018-10-10-ENGLISH.*
    Caller:..tba.*
    Band:..schedule.not.yet.published.*
    2018-10-24-ENGLISH.*
    2018-11-14-ENGLISH.*
    2018-11-28-ENGLISH.*
    2018-12-12-ENGLISH.*
}msx, 'workshops look ok';


# *****************
# multiple days
$ENV{QUERY_STRING} = 'style=ENGLISH&venues=ASE,FBC,MT,FHL,SME&day=Tue&day2=Wed&day3=Thu';
($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
like $stdout, qr{
    2018-09-18-ENGLISH.*
    Tuesday,.September.18.*
    All.Saints.Episcopal.Church,.555.Waverley.St,.Palo.Alto.*
    Caller:..Alan.Winston.*
    Band:..Audrey.Knuth,.Christopher.Jacoby,.Bill.Jensen.*
    2018-10-02-ENGLISH.*
    Tuesday,.October.2.*
    Caller:..tba.*
    Band:..schedule.not.yet.published.*
    2018-10-16-ENGLISH.*
    2018-11-06-ENGLISH.*
    2018-12-04-ENGLISH.*
    2018-12-18-ENGLISH.*
}msx, 'day,day2,day3 handling looks ok';

# *****************
# single event, with json-ld
$ENV{QUERY_STRING} = 'single-event=2018-09-18&venue=ASE&starttime=18:00&endtime=22:00';
#2018-09-18||ENGLISH|ASE|Alan Winston|Audrey Knuth, Christopher Jacoby, Bill Jensen
($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
like $stdout,
qr{^<a name="2018-09-18-ENGLISH"></a>
<p class="dance">
<b class="date">
<a href="\?single-event=2018-09-18">
Tuesday, September 18
</a></b><br />
All Saints Episcopal Church, 555 Waverley St, Palo Alto <br />
Caller:  Alan Winston<br />
Band:  Audrey Knuth, Christopher Jacoby, Bill Jensen<br /><br />
</p>
}ms, 'single event handling';


($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
$stdout =~ m{<script.*?>(.+?)</script>}ms
    or die "can't find <script> tags in $stdout";

my $got_json = $1;
my $got = from_json($got_json);

is $got->{'@context'}, 'http://schema.org';
is_deeply $got->{'@type'}, [qw/Event DanceEvent/];
is $got->{name}, 'English Dancing, calling by Alan Winston to the music of Audrey Knuth, Christopher Jacoby, Bill Jensen';
is $got->{startDate}, '2018-09-18T18:00';
is $got->{endDate}, '2018-09-18T22:00';
is $got->{eventAttendanceMode}, 'https://schema.org/OfflineEventAttendanceMode';
like $got->{eventStatus}, qr{https://schema.org/Event(Scheduled|Cancelled)};
is_deeply $got->{organizer}, {
        '@context' => 'http://schema.org',
        '@type' => 'Organization',
        'name' => 'Bay Area Country Dance Society',
        'url' => 'https://www.bacds.org/'
};
is_deeply $got->{location}, {
        '@context' => 'http://schema.org',
        '@type' => 'Place',
        'name' => 'All Saints Episcopal Church',
        'address' => {
            '@type' => 'PostalAddress',
            'streetAddress' => '555 Waverley St',
            'addressLocality' => 'Palo Alto',
            'addressCountry' => 'USA',
            'postalCode' => '',
            'addressRegion' => 'California',
        },
};
like $got->{description}, qr{^English Dancing at All Saints Episcopal Church in Palo Alto. Everyone welcome, beginners and experts! No partner necessary. Say Yes to Hambo!};

=pod

this is what it looks like:

<script type="application/ld\+json">
{
    "\@context":"http://schema.org",
    "\@type":."Event","DanceEvent".,
    "name":"English Dancing, calling by Alan Winston to the music of Audrey Knuth, Christopher Jacoby, Bill Jensen",
    "startDate":"2018-09-18T18:00",
    "endDate":"2018-09-18T22:00",
    "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
    "eventStatus": "https://schema.org/Event(Scheduled|Cancelled)",
    "organizer":
    {
        "\@context":"http://schema.org",
        "\@type":"Organization",
        "name":"Bay Area Country Dance Society",
        "url":"https://www.bacds.org/"
    },
    "location":
    {
        "\@context":"http://schema.org",
        "\@type":"Place",
        "name":"All Saints Episcopal Church",
        "address":
        {
            "\@type":"PostalAddress",
            "streetAddress":"555 Waverley St",
            "addressLocality":"Palo Alto",
...
=cut



# *****************
# crap, need to support multiple venues
$ENV{QUERY_STRING} = 'single-event=2018-09-18&venues=CCB,ASE,USA,WTFBBQLOL&starttime=19:30&endtime=23:00';
#2018-09-18||ENGLISH|ASE|Alan Winston|Audrey Knuth, Christopher Jacoby, Bill Jensen
($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
like $stdout,
qr{^<a name="2018-09-18-ENGLISH"></a>
<p class="dance">
<b class="date">
<a href="\?single-event=2018-09-18">
Tuesday, September 18
</a></b><br />
All Saints Episcopal Church, 555 Waverley St, Palo Alto <br />
Caller:  Alan Winston<br />
Band:  Audrey Knuth, Christopher Jacoby, Bill Jensen<br /><br />
</p>
}ms, 'single event handling';


($stdout, $stderr, $exit) = capture {
    system "scripts/serieslists.pl";
};
if ($exit) {
    die $stdout.$stderr;
}
say STDERR $stderr if $stderr;
$stdout =~ m{<script.*?>(.+?)</script>}ms
    or die "can't find <script> tags in $stdout";

$got_json = $1;
$got = from_json($got_json);

is $got->{'@context'}, 'http://schema.org';
is_deeply $got->{'@type'}, [qw/Event DanceEvent/];
is $got->{name}, 'English Dancing, calling by Alan Winston to the music of Audrey Knuth, Christopher Jacoby, Bill Jensen';
is $got->{startDate}, '2018-09-18T19:30';
is $got->{endDate}, '2018-09-18T23:00';
is $got->{eventAttendanceMode}, 'https://schema.org/OfflineEventAttendanceMode';
like $got->{eventStatus}, qr{https://schema.org/Event(Scheduled|Cancelled)};
is_deeply $got->{organizer}, {
        '@context' => 'http://schema.org',
        '@type' => 'Organization',
        'name' => 'Bay Area Country Dance Society',
        'url' => 'https://www.bacds.org/'
};
is_deeply $got->{location}, {
        '@context' => 'http://schema.org',
        '@type' => 'Place',
        'name' => 'All Saints Episcopal Church',
        'address' => {
            '@type' => 'PostalAddress',
            'streetAddress' => '555 Waverley St',
            'addressLocality' => 'Palo Alto',
            'addressCountry' => 'USA',
            'postalCode' => '',
            'addressRegion' => 'California',
        },
};
like $got->{description}, qr{^English Dancing at All Saints Episcopal Church in Palo Alto. Everyone welcome, beginners and experts! No partner necessary. Say Yes to Hambo!};


# vim: tabstop=4 shiftwidth=4 expandtab

