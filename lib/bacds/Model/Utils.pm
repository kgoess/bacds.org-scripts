
package bacds::Model::Utils;

use warnings;
use 5.16.0;

use DateTime;
use DBI;

use parent qw( Exporter );

our @EXPORT_OK = qw/
    get_dbh
    csv_dir
    now_iso8601
/;

my $DEFAULT_CSV_DIR = '/var/www/bacds.org/public_html/data';

sub get_dbh {
    my $csv_dir = csv_dir();
    return DBI->connect(
        qq[DBI:CSV:f_dir=$csv_dir;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\], '', ''
    );
};

sub csv_dir {
    return $ENV{TEST_CSV_DIR} || $DEFAULT_CSV_DIR;
}


# this is only for database timestamp columns, it's the full
# YYYY-MM-DDTHH:MM:SS
sub now_iso8601 {
    # I *think* it'll keep things simple to have everything in the pacific
    # timezone
    return DateTime->now(time_zone => 'America/Los_Angeles')->iso8601;
}
