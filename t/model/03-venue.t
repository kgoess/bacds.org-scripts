#!/usr/bin/perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use File::Path qw/rmtree/;
use File::Temp qw/tempdir/;
use Test::More tests => 15;

use bacds::Model::Venue;


my $datadir = tempdir();
$ENV{TEST_CSV_DIR} = $datadir;

eval {
    bacds::Model::Venue->create_table;

    test_CRUD();
    test_load_all();

    rmtree $datadir;

    1;
} or do {
    say "\nYour data is in $datadir if you want to look at it\n\n";
    die $@;
};

sub test_CRUD {
    my $venue = bacds::Model::Venue->new(
        vkey    => 'CCB',
        hall    => 'Christ Church Berkeley (formerly Grace North Church)',
        address    => '2138 Cedar Street',
        city    => 'Berkeley',
        #zip
        comment    => 'Between Walnut and Oxford',
        type    => 'SERIES',
    );

    #
    # save it to the db
    #
    $venue->save;

    #
    # load it back from the db
    #
    my $loaded = bacds::Model::Venue->load(venue_id => $venue->venue_id);

    is $loaded->vkey, 'CCB';
    is $loaded->hall, 'Christ Church Berkeley (formerly Grace North Church)';
    is $loaded->address, '2138 Cedar Street';
    is $loaded->city, 'Berkeley';
    is $loaded->zip, '';
    is $loaded->comment, 'Between Walnut and Oxford';
    is $loaded->type, 'SERIES';

    #
    # update a field
    #
    $loaded->address('123 Updated St.');
    $loaded->update;

    #
    # load the update
    #
    my $after_update = bacds::Model::Venue->load(venue_id => $venue->venue_id);
    is $after_update->address, '123 Updated St.';
    is $after_update->city, 'Berkeley';
    is $after_update->vkey, 'CCB';

    #
    # load by vkey
    #
    $loaded = bacds::Model::Venue->load(vkey => $venue->vkey);
    is $loaded->venue_id, $venue->venue_id;
    is $loaded->vkey, $venue->vkey;

    #
    # delete
    #
    $venue->delete;

    ok ! bacds::Model::Venue->load(venue_id => $venue->venue_id);

    #
    # check the serial
    #
    my $venue_2 = bacds::Model::Venue->new(
        startday      => '2022-01-01',
    );
    $venue_2->save;
    is $venue_2->venue_id, 2;

    $venue_2->delete;
}

sub test_load_all {

    bacds::Model::Venue->new(
        vkey    => 'VV1',
        hall    => 'Venue 1',
        type    => 'SERIES',
    )->save;
    bacds::Model::Venue->new(
        vkey    => 'VV2',
        hall    => 'Venue 2',
        type    => 'SERIES',
    )->save;


    my @all = bacds::Model::Venue->load_all();

    is @all, 2, "no params, got all two";

}
