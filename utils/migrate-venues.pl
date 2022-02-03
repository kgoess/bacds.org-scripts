#!/usr/bin/perl

use 5.16.0;
use warnings;

use File::Copy qw/move/;
use Getopt::Long;

use bacds::Model::Venue;

my ($data_dir);
GetOptions ("data-dir=s" => \$data_dir);

$data_dir or die "Usage: $0 --data-dir /path/some/where";

-d $data_dir or die "can't find $data_dir";

my $path_to_venue = "$data_dir/venue";
-f $path_to_venue or die "can't find $path_to_venue";

$ENV{TEST_CSV_DIR} = $data_dir;

move $path_to_venue, "$path_to_venue.old"
    or die "can't move to $path_to_venue.old $!";

bacds::Model::Venue->create_table;

my @venues = bacds::Model::Venue->load_all_from_old_schema(table => 'venue.old');


foreach my $venue (@venues) {
    $venue->save;
}
