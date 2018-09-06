# some basic tests for serieslists.pl as I change it around


use 5.14.0;
use warnings;

use Test::More tests => 2;
use Test::Output qw/stdout_like/;


$ENV{REQUEST_METHOD} = '';
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
Band:..Phoenix.Rising.\(William.Allen,.Mary.Tabor,.Robin.Lockner\)..&mdash;season.opening.party!.Workshop.2:10,.Dance.2:30&ndash;5:00.*
2018-10-14-ENGLISH.*
Sunday,.October.14.*
Caller:..tba.*
Band:..schedule.not.yet.published.*
2018-11-11-ENGLISH.*
2018-12-09-ENGLISH.*
}msx, 'COY,FSJ english looks ok';


# vim: tabstop=4 shiftwidth=4 expandtab

