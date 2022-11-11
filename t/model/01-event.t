#!/usr/bin/perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use File::Path qw/rmtree/;
use File::Temp qw/tempdir/;
use List::MoreUtils qw/any/;
use Test::More tests => 37;

use bacds::Model::Event;


my $datadir = tempdir();
$ENV{TEST_CSV_DIR} = $datadir;

eval {
    bacds::Model::Event->create_table;

    test_CRUD();
    test_load_all();
    test_load_all_style_in_list();
    test_load_all_venue_in_list();
    test_load_all_on_date();
    test_load_events_for_month();

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

    $_->delete for @all;
}

# testing the style_in_list => [ENGLISH, CONTRA] arg
sub test_load_all_style_in_list {

    bacds::Model::Event->new(startday => "2022-01-0$_", type => 'STYLE1')->save
        for (1, 2);

    bacds::Model::Event->new(startday => "2022-01-0$_", type => 'STYLE2')->save
        for (1, 2);

    bacds::Model::Event->new(startday => "2022-01-0$_", type => 'STYLE3')->save
        for (1, 2);

    my @got;

    # one of the styles
    @got = bacds::Model::Event->load_all( style_in_list => ['STYLE1']);
    is @got, 2, 'just STYLE1' or dump \@got;


    # two of the styles
    @got = bacds::Model::Event->load_all( style_in_list => ['STYLE1', 'STYLE2']);
    is @got, 4, 'STYLE1 and STYLE2' or dump \@got;

    # two styles and a date
    @got = bacds::Model::Event->load_all(
        style_in_list => ['STYLE1', 'STYLE2'],
        after => '2022-01-02',
    );
    is @got, 2, 'STYLE1 and STYLE2 just on Jan 2nd' or dump \@got;
    is_deeply [sort map { $_->type } @got], [sort (qw/STYLE1 STYLE2/)],
        'one of each of the two for the 2nd' or dump \@got;

    $_->delete for bacds::Model::Event->load_all;
}


# testing the venue_in_list => [CCB, SPF] arg
sub test_load_all_venue_in_list {

    bacds::Model::Event->new(startday => "2022-01-0$_", loc => 'VENUE1')->save
        for (1, 2);

    bacds::Model::Event->new(startday => "2022-01-0$_", loc => 'VENUE2')->save
        for (1, 2);

    bacds::Model::Event->new(startday => "2022-01-0$_", loc => 'VENUE3')->save
        for (1, 2);

    my @got;

    # one of the venues
    @got = bacds::Model::Event->load_all( venue_in_list => ['VENUE1']);
    is @got, 2, 'just VENUE1' or dump \@got;


    # two of the venues
    @got = bacds::Model::Event->load_all( venue_in_list => ['VENUE1', 'VENUE2']);
    is @got, 4, 'VENUE1 and VENUE2' or dump \@got;

    # two venues and a date
    @got = bacds::Model::Event->load_all(
        venue_in_list => ['VENUE1', 'VENUE2'],
        after => '2022-01-02',
    );
    is @got, 2, 'VENUE1 and VENUE2 just on Jan 2nd' or dump \@got;
    is_deeply [sort map { $_->loc } @got], [sort (qw/VENUE1 VENUE2/)],
        'one of each of the two for the 2nd' or dump \@got;

    $_->delete for bacds::Model::Event->load_all;
}


sub test_load_all_on_date {

    bacds::Model::Event->new(startday => "2022-01-0$_", loc => 'VENUE1')->save
        for (1, 2);

    bacds::Model::Event->new(startday => "2022-01-0$_", loc => 'VENUE2')->save
        for (1, 2);

    bacds::Model::Event->new(startday => "2022-01-0$_", loc => 'VENUE3')->save
        for (1, 2);

    my @got;

    # one of the venues
    @got = bacds::Model::Event->load_all(
        on_date => '2022-01-01',
        venue_in_list => ['VENUE1'],
    );
    is @got, 1, 'one VENUE1 on jan 1' or dump \@got;

    @got = bacds::Model::Event->load_all(
        on_date => '2022-01-01',
        venue_in_list => ['VENUE1', 'VENUE2'],
    );
    is @got, 2, 'two for VENUE1 and VENUE2 on jan 1' or dump \@got;

    $_->delete for bacds::Model::Event->load_all;
}

sub test_load_events_for_month {

    # using the dame data as t/calendar2-2.t
    local $ENV{TEST_CSV_DIR} = 't/data';

    my @got;

    # make sure the results are the same as t/calendar2-2.t
    @got = bacds::Model::Event->load_events_for_month('2018', '02');
    is @got, 22;
    is $got[0]->type, 'ENGLISH';
    is $got[0]->loc, 'MT';
    is $got[0]->leader, 'Alisa Dodson (2018 Playford Ball Ogre)';
    is $got[21]->type, 'ENGLISH';
    is $got[21]->loc, 'CCB';
    is $got[21]->leader, 'Kalia Kliban';

    #
    # august has a bunch of camps, but none of them cross the month boundary
    #
    @got = bacds::Model::Event->load_events_for_month('2018', '08');
    is @got, 26;

    #
    # we made a test camp that cross the November/December boundary, should
    # show up in each
    #
    @got = bacds::Model::Event->load_events_for_month('2018', '11');
    ok any {$_->comments eq 'Test Camp That Crosses Month Boundary' } @got;
    is $got[0]->startday, '2018-11-02';

    @got = bacds::Model::Event->load_events_for_month('2018', '12');
    ok any {$_->comments eq 'Test Camp That Crosses Month Boundary' } @got;
    is $got[0]->startday, '2018-11-30';
    is $got[1]->startday, '2018-12-01';
}
