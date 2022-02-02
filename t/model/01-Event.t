#!/usr/bin/perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use File::Path qw/rmtree/;
use File::Temp qw/tempdir/;
use Test::More tests => 14;

use bacds::Model::Event;


my $datadir = tempdir();
$ENV{TEST_CSV_DIR} = $datadir;

eval {
    bacds::Model::Event->create_table;

    test_CRUD();
    test_load_all();

    rmtree $datadir;

    1;
} or do {
    say "\nYour data is in $datadir if you want to look at it\n\n";
    die $@;
};

sub test_CRUD {
    my $event = bacds::Model::Event->new(
        startday      => '2022-01-01',
        endday        => '',
        type          => 'ENGLISH',
        loc           => 'CCB',
        leader        => 'Alice le Caller',
        band          => 'Bob, Carol, &amp; Dan',
        comments      => '',
        url           => '',
        photo         => '',
        performer_url => 'https://the-band.com',
        pacific_time  => '18:00',
    );

    #
    # save it to the db
    #
    $event->save;

    #
    # load it back from the db
    #
    my $loaded = bacds::Model::Event->load(event_id => $event->event_id);

    is $loaded->startday, '2022-01-01';
    is $loaded->endday, '';
    is $loaded->type, 'ENGLISH';
    is $loaded->loc, 'CCB';
    is $loaded->leader, 'Alice le Caller';
    is $loaded->band, 'Bob, Carol, &amp; Dan';

    #
    # update a field
    #
    $loaded->band('some other band');
    $loaded->update;

    #
    # load the update
    #
    my $after_update = bacds::Model::Event->load(event_id => $event->event_id);
    is $after_update->startday, '2022-01-01';
    is $loaded->endday, '';
    is $loaded->band, 'some other band';

    #
    # delete
    #
    $event->delete;

    ok ! bacds::Model::Event->load(event_id => $event->event_id);

    #
    # check the serial
    #
    my $event_2 = bacds::Model::Event->new(
        startday      => '2022-01-01',
    );
    $event_2->save;
    is $event_2->event_id, 2;

    $event_2->delete;
}

sub test_load_all {

    bacds::Model::Event->new(startday => "2022-01-0$_")->save
        for (1, 2, 3, 4);

    my @all = bacds::Model::Event->load_all();

    is @all, 4, "no params, got all four";

    my @last_three = bacds::Model::Event->load_all(after => '2022-01-02');
    is @last_three, 3, "after 01-02 (inclusive), there's three";


    my @middle_two = bacds::Model::Event->load_all(after => '2022-01-02', before => '2022-01-04');
    is @middle_two, 2, "after 01-02 (inclusive) and before 01-04, there's two";
}
