
package bacds::Utils;

use warnings;
use 5.16.0;

use CGI::Cookie;
use DateTime;

use parent qw( Exporter );

our @EXPORT_OK = qw/
    today_ymd
    get_dbix_test_cookie
/;


sub today_ymd {
    return $ENV{TEST_TODAY} ||
            DateTime->now(time_zone => 'America/Los_Angeles')->ymd
}

# for testing the new code before rollout
sub get_dbix_test_cookie {
    my %cookies;

    if ($ENV{COOKIE}) { # unit tests
        %cookies = CGI::Cookie->parse($ENV{COOKIE});
    } else {
        %cookies = CGI::Cookie->fetch;
    }

    if (my $test_cookie = $cookies{DBIX_TEST}) {
        return $test_cookie->value;
    }
    return;
}

1;
