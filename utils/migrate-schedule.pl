#!/usr/bin/perl

# This only migrates the 2022 table. Add calls to load_all_from_old_schema and
# load_all_from_really_old_schema for the rest of them

use 5.16.0;
use warnings;

use DateTime;
use File::Copy qw/move/;
use Getopt::Long;

use bacds::Model::Event;

my ($data_dir, $migrate_from_filename, $which_old_schema);
GetOptions (
    "data-dir=s" => \$data_dir,
    "migrate-from=s" => \$migrate_from_filename,
    "which-old-schema=s" => \$which_old_schema,
);

($data_dir and $migrate_from_filename)
    or die usage();

$which_old_schema =~ /^ (old|really_old) $/x
    or die usage();

-d $data_dir or die "can't find $data_dir";

my $path_to_schedule = "$data_dir/$migrate_from_filename";
-f $path_to_schedule or die "can't find $path_to_schedule";

$ENV{TEST_CSV_DIR} = $data_dir;

my $now = DateTime->now->ymd('').DateTime->now->hms('');

move $path_to_schedule, "$path_to_schedule$now"
    or die "can't move to $path_to_schedule$now $!";

bacds::Model::Event->create_table;

my $load_method = "load_all_from_${which_old_schema}_schema";

my @events = bacds::Model::Event->$load_method(table => "$migrate_from_filename$now");
#my @events = bacds::Model::Event->load_all_from_old_schema(table => "$migrate_from$now");
#my @events = bacds::Model::Event->load_all_from_really_old_schema(table => "$migrate_from$now");


foreach my $event (@events) {
    say join ' ', 'migrating', grep $_, map { $event->$_ } qw/startday type loc leader/;
    $event->save;
}

sub usage {
    return <<EOL;
Usage: $0
    --data-dir /path/some/where
    --migrate-from schedule2017
    --which-old-schema  (old|really_old)
EOL
}

