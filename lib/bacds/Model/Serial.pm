=head1 NAME

bacds::Model::Serial - a counter for DBD::CSV tables

=cut

package bacds::Model::Serial;

use warnings;
use 5.16.0;

use Carp qw/croak/;
use Fcntl qw(LOCK_EX);

use bacds::Model::Utils qw/csv_dir/;

sub get_next {
    my ($class, $name) = @_;

    $name or croak "you didn't give $class a 'name'";

    my $db_dir = csv_dir();
    my $lock_path = "$db_dir/$name.lock";

    if (!-e $lock_path) {
        open my $fh, '>>', $lock_path
            or croak "can't create $lock_path $!";
        close $fh;
    }

    # https://perlmaven.com/open-to-read-and-write
    open my $fh, '+<', $lock_path
        or croak "can't open $lock_path for writing+locking $!";

    flock($fh, LOCK_EX) or die "Cannot lock mailbox - $!\n";

    my $serial = <$fh>;
    $serial++;
    seek $fh, 0, 0;
    truncate $fh, 0;
    print $fh $serial;
    close $fh;

    return $serial;
}


1;
