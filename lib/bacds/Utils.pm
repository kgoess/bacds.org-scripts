
package bacds::Utils;

use warnings;
use 5.16.0;

use DateTime;

use parent qw( Exporter );

our @EXPORT_OK = qw/
    today_ymd
/;


sub today_ymd {
    return $ENV{TEST_TODAY} ||
            DateTime->now(time_zone => 'America/Los_Angeles')->ymd
}

1;
