#!/usr/bin/perl

use warnings;
use 5.16.0;

use File::Temp qw/tempdir/;
use Test::More tests => 3;

use bacds::Model::Serial;

my $datadir = tempdir(CLEANUP => 1);
$ENV{TEST_CSV_DIR} = $datadir;

is(bacds::Model::Serial->get_next('mytest'), 1);
is(bacds::Model::Serial->get_next('mytest'), 2);
is(bacds::Model::Serial->get_next('mytest'), 3);
