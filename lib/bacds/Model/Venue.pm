
package bacds::Model::Venue;

use warnings;
use 5.16.0;

use Carp qw/croak/;
use DateTime;

use bacds::Model::Serial;
use bacds::Model::Utils qw/get_dbh/;

my @Columns = (
    'venue_id',     # the primary key, supplied by the db
    'vkey',         # ACC, ALB, etc.
    'hall',         # full name, "Albany Veteran's Memorial Building"
    'address',      # street address
    'city',         # 
    'zip',          # 
    'comment',      #
    'type',         # e.g. .SPECIAL, SERIES, CAMP, SPECIAL/CONTRA

    'created_ts',    # filled by the db
    'modified_ts',   # filled by the db
);

use Class::Accessor::Lite(
    new => 1,
);

Class::Accessor::Lite->mk_accessors(@Columns);

=head2 save

$venue->save writes a new venue to the db, will fall back to $venue->update
if there's already an venue_id.

=cut

sub save {
    my ($self) = @_;

    # validate?

    if ($self->venue_id) {
        return $self->update;
    }

    $self->venue_id(bacds::Model::Serial->get_next('venue'));
    $self->created_ts(DateTime->now->iso8601);
    $self->modified_ts(DateTime->now->iso8601);

    my $stmt = 
        'INSERT INTO venue ('.
        join(', ', @Columns)
        .') values ('.
        join(',', ('?')x@Columns)
        .')';
    
    my $dbh = get_dbh;

    my $sth = $dbh->prepare($stmt);
    $sth->execute( map { $self->$_ } @Columns ) or die $sth->errstr;

    1;
}

=head2 load(venue_id => 1234)

=cut

sub load {
    my ($class, %args) = @_;

    my $venue_id = $args{venue_id}
        or croak "missing venue_id in call to $class->load";

    my $stmt =
        'SELECT '.
        join(', ', @Columns).
        " FROM venue WHERE venue_id = ? ";

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;
    $sth->execute($venue_id)
        or die $sth->errstr;

    my $row = $sth->fetchrow_hashref
        or return;

    return $class->new($row);
}

=head2 load_all

Returns all the $venue objects as a list.

=cut

sub load_all {
    my ($class, %args) = @_;

    my $stmt =
        'SELECT '.
        join(', ', @Columns).
        " FROM venue";


    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die "prepare failed for '$stmt' ".$dbh->errstr;
    $sth->execute()
        or die $sth->errstr;

    my @found;
    while (my $row = $sth->fetchrow_hashref) {
        push @found, $class->new($row);
    }
    return @found;
}


=head2 update

$venue->update writes the data currently in the object to the db

=cut

sub update {
    my ($self) = @_;

    $self->venue_id
        or croak "can't call update on an venue without an venue_id";

    my $stmt =
        'UPDATE VENUE SET '.
        join(', ', map { "$_ = ?" } @Columns ).
        ' WHERE venue_id = ? ';

    my $dbh = get_dbh;
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;

    $sth->execute(map $self->$_, @Columns, 'venue_id')
        or die $sth->errstr;

    1;
}

=head2 delete

$venue->delete removes it from the database.

=cut

sub delete {
    my ($self) = @_;

    my $venue_id = $self->venue_id
        or croak "can't call delete on an venue without an venue_id";

    my $stmt = 'DELETE FROM venue WHERE venue_id = ?';

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;

    $sth->execute($venue_id)
        or die $sth->errstr;

    1;
}

=head2 create_table

Used by the unit tests, this also documents the table schema.

=cut

sub create_table {

    my $dbh = get_dbh();

    # untested in postgres and sqlite, DBD::CSV will ignore the attributes
    my $ddl = 'CREATE TABLE venue (
        venue_id INT, -- BIGSERIAL PRIMARY KEY,
        vkey CHAR(10) NOT NULL,
        hall VARCHAR(64) NOT NULL,
        address VARCHAR(128) NOT NULL,
        city VARCHAR(32) NOT NULL,
        zip CHAR(10),
        comment VARCHAR(256),
        type CHAR(16),
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
