# some basic tests for serieslists.pl as I change it around


use 5.14.0;
use warnings;

use Test::More tests => 4;
use Test::Output qw/stdout_like/;

$ENV{TEST_CSV_DIR} = 't/data/';
$ENV{TEST_NOW} = '1536267581';

$ENV{QUERY_STRING} = 'styles=CONTRA,HAMBO&venues=HVC&day=Sun';
stdout_like {
    do 'bin/serieslists.pl';
} qr{
    2018-09-23-CONTRA.*
    Sunday,.September.23.*
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


$ENV{QUERY_STRING} = 'venues=COY,FSJ&day=Sun&style=ENGLISH';
stdout_like {
    do 'bin/serieslists.pl';
} qr{
2018-09-09-ENGLISH.*
Sunday,.September.9.*
Caller:..Alexandra.Deis-Lauby.\[NYC\].*
Band:..Phoenix.Rising.\(William.Allen,.Mary.Tabor,.Robin.Lockner\)..&mdash;season.opening.party!.Workshop.2:10,.Dance.2:30.*
2018-10-14-ENGLISH.*
Sunday,.October.14.*
Caller:..tba.*
Band:..schedule.not.yet.published.*
2018-11-11-ENGLISH.*
2018-12-09-ENGLISH.*
}msx, 'COY,FSJ english looks ok';


$ENV{QUERY_STRING} = 'styles=ENGLISH,ECDWORKSHOP&venues=STC,CCB,STALB&day=Wed';
stdout_like {
    do 'bin/serieslists.pl';
} qr{
    <!--.TYPE.=.ENGLISH/WORKSHOP.-->.*
    <div.class="workshop">.*
    <a.name="2018-09-12-ENGLISH/WORKSHOP"></a>.*
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

$ENV{QUERY_STRING} = 'style=ENGLISH&venues=ASE,FBC,MT,FHL,SME&day=Tue&day2=Wed&day3=Thu';
stdout_like {
    do 'bin/serieslists.pl';
} qr{
    2018-09-18-ENGLISH.*
    Tuesday,.September.18.*
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


# vim: tabstop=4 shiftwidth=4 expandtab

