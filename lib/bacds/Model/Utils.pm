
package bacds::Model::Utils;

use warnings;
use 5.16.0;

use parent qw( Exporter );

our @EXPORT_OK = qw/
    get_dbh
    csv_dir
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

