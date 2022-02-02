=head1 NAME

bacds::Model::Event - ORM to the schedule table

=head1 DESCRIPTION

Each row in the schedule table is an "Event". This is an
interface to that table.

=cut

package bacds::Model::Event;

use warnings;
use 5.16.0;

use Carp qw/croak/;
use DateTime;

use bacds::Model::Serial;
use bacds::Model::Utils qw/get_dbh/;

my @Columns = (
    'event_id',     # the primary key, supplied by the db
    'startday',     # YYYY-MM-DD
    'endday',
    'type',         # "ENGLISH" or "ONLINE Concert & Dance"
    'loc',          # "CCB" or "ONLINE"
    'leader',       # "Bruce Hamilton"
    'band',         # can include HTML, links, etc.
    'comments',
    'url',
    'photo',         # Photo - filepath or URL to photo to use for event listing (only 1)
    'performer_url', # PerformerURL - web site for band or caller, again, only 1
    'pacific_time',  # PacificTime - 24hr event start time to plug into time zone converter

    'created_ts',    # filled by the db
    'modified_ts',   # filled by the db
);

use Class::Accessor::Lite(
    new => 1,
);

Class::Accessor::Lite->mk_accessors(@Columns);

=head2 save

$event->save writes a new event to the db, will fall back to $event->update
if there's already an event_id.

=cut

sub save {
    my ($self) = @_;

    # validate?

    if ($self->event_id) {
        return $self->update;
    }

    $self->event_id(bacds::Model::Serial->get_next('schedule'));
    $self->created_ts(DateTime->now->iso8601);
    $self->modified_ts(DateTime->now->iso8601);

    my $stmt = 
        'INSERT INTO schedule ('.
        join(', ', @Columns)
        .') values ('.
        join(',', ('?')x@Columns)
        .')';
    
    my $dbh = get_dbh;

    my $sth = $dbh->prepare($stmt);
    $sth->execute( map { $self->$_ } @Columns ) or die $sth->errstr;

    1;
}

=head2 load(event_id => 1234)

=cut

sub load {
    my ($class, %args) = @_;

    my $event_id = $args{event_id}
        or croak "missing event_id in call to $class->load";

    my $table = lc($args{table} || 'schedule');

    my $stmt =
        'SELECT '.
        join(', ', @Columns).
        " FROM $table WHERE event_id = ? ";

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;
    $sth->execute($event_id)
        or die $sth->errstr;

    my $row = $sth->fetchrow_hashref
        or return;

    return $class->new($row);
}

=head2 load_all(%args)

Load all the events from $args{table}, returns the objects
as a list..

%args can include:

 - $args{after} = YYYY-MM-DD (inclusive)
 - $args{before} = YYYY-MM-DD (exclusive)

=cut

sub load_all {
    my ($class, %args) = @_;

    my $table = lc($args{table} || 'schedule');


    my $stmt =
        'SELECT '.
        join(', ', @Columns).
        " FROM $table";

    my (@where_clauses, @where_params);
    
    
    if (my $after = $args{after}) {
        croak "invalid value for 'after': $after"
            unless $after =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
        push @where_clauses, 'startday >= ?';
        push @where_params, $after;
    }

    if (my $before = $args{before}) {
        croak "invalid value for 'before': $before"
            unless $before =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
        push @where_clauses, 'startday < ?';
        push @where_params, $before;
    }

    if (@where_clauses) {
        $stmt .= ' WHERE '.join(' AND ', @where_clauses);
    }

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die "prepare failed for '$stmt' ".$dbh->errstr;
    $sth->execute(@where_params)
        or die $sth->errstr;

    my @found;
    while (my $row = $sth->fetchrow_hashref) {
        push @found, $class->new($row);
    }
    return @found;
}

=head2 load_all_from_old_schema

Works on the csv schema from 2021, early 2022

=cut

sub load_all_from_old_schema {
    my ($class, %args) = @_;

    my $table = $args{table}
        or die "missing 'table' arg in call to load_all_from_old_schema";

    my @old_columns = qw/
        startday
        endday
        type
        loc
        leader
        band
        comments
        url
        photo
        performer_url
        pacific_time
    /;

    my $stmt =
        'SELECT '.
        join(', ', @old_columns).
        " FROM $table";

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;
    $sth->execute()
        or die $sth->errstr;

    my @found;
    while (my $row = $sth->fetchrow_hashref) {
        push @found, $class->new($row);
    }
    return @found;
}

=head2 load_all_from_really_old_schema

Works on the csv schema through 2020

=cut

sub load_all_from_really_old_schema {
    my ($class, %args) = @_;

    my $table = $args{table}
        or die "missing 'table' arg in call to load_all_from_old_schema";

    my @old_columns = qw/
        startday
        endday
        type
        loc
        leader
        band
        comments
        name
        stdloc
        url
    /;

    my $stmt =
        'SELECT '.
        join(', ', @old_columns).
        " FROM $table";

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;
    $sth->execute()
        or die $sth->errstr;

    my @found;
    while (my $row = $sth->fetchrow_hashref) {
        push @found, $class->new($row);
    }
    return @found;
}

=head2 update

$event->update writes the data currently in the object to the db

=cut

sub update {
    my ($self) = @_;

    $self->event_id
        or croak "can't call update on an event without an event_id";

    my $stmt =
        'UPDATE schedule SET '.
        join(', ', map { "$_ = ?" } @Columns ).
        ' WHERE event_id = ? ';

    my $dbh = get_dbh;
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;

    $sth->execute(map $self->$_, @Columns, 'event_id')
        or die $sth->errstr;

    1;
}

=head2 delete

$event->delete removes it from the database.

=cut

sub delete {
    my ($self) = @_;

    my $event_id = $self->event_id
        or croak "can't call delete on an event without an event_id";

    my $stmt = 'DELETE FROM schedule WHERE event_id = ?';

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;

    $sth->execute($event_id)
        or die $sth->errstr;

    1;
}

=head2 create_table

Used by the unit tests, this also documents the table schema.

=cut

sub create_table {

    my $dbh = get_dbh();

    # untested in postgres and sqlite, DBD::CSV will ignore the attributes
    my $ddl = 'CREATE TABLE schedule (
        event_id INT, -- BIGSERIAL PRIMARY KEY,
        startday CHAR(10) NOT NULL,
        endday CHAR(10),
        type VARCHAR(32) NOT NULL,
        loc VARCHAR(32) NOT NULL,
        leader VARCHAR(128),
        band VARCHAR(2048),
        comments VARCHAR(2048),
        url VARCHAR(128),
        photo VARCHAR(128),
        performer_url VARCHAR(128),
        pacific_time CHAR(5),
             -- *_ts can be input as 1999-01-08 04:05:06 America/Los_Angeles
        created_ts CHAR(32), -- TIMESTAMP WITH TIME ZONE DEFAULT NOW,
        modified_ts CHAR(32), -- TIMESTAMP WITH TIME ZONE DEFAULT NOW,
    )';
    # DBD::CSV doesn't like comments
    $ddl =~ s/--.*//g;

    $dbh->do($ddl)
        or die $dbh->errstr;
}


1;
