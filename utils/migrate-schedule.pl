#!/usr/bin/perl

# UNTESTED
# This only migrates the 2018 table. Add calls to load_all_from_old_schema and
# load_all_from_really_old_schema for the rest of them

use 5.16.0;
use warnings;

use File::Copy qw/move/;
use Getopt::Long;

use bacds::Model::Event;

my ($data_dir);
GetOptions ("data-dir=s" => \$data_dir);

$data_dir or die "Usage: $0 --data-dir /path/some/where";

-d $data_dir or die "can't find $data_dir";

my $path_to_schedule = "$data_dir/schedule";
-f $path_to_schedule or die "can't find $path_to_schedule";

$ENV{TEST_CSV_DIR} = $data_dir;

move $path_to_schedule, "$path_to_schedule.old"
    or die "can't move to $path_to_schedule.old $!";

bacds::Model::Event->create_table;

my @events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule.old');


foreach my $event (@events) {
    $event->save;
}
