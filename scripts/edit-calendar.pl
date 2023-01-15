#!/usr/bin/perl

use 5.16.0;
use warnings;

use Curses;
use Curses::UI;
use Data::Dump qw/dump/;
use DateTime;
use File::Basename;
use Getopt::Long;

use bacds::Model::Event;
use bacds::Model::Venue;
use bacds::Model::Utils qw/csv_dir/;

my $logfile = "/tmp/" . basename "$0.$<.log";

my $db_file = csv_dir() . "/schedule";
if (!-w  $db_file) {
    die "You don't have write permissions to the db file:\n\t$db_file\nPlease fix that up before continuing";
}

my ($help);
GetOptions (
    "h|help" => \$help
);

if ($help) {
    say <<USAGE;

usage: $0
  --help this help

Set TEST_CSV_DIR in your environment to use something else
besides '/var/www/bacds.org/public_html/data'.

Errors can be found in $logfile
USAGE
    exit;
}

if ($< == 0) {
    die "You don't need to run this as root, or under sudo. Just be yourself!\n(assuming you're a member of the 'apache' group)\n";
}

check_sequence_file();



my $debug = 0;

$SIG{__DIE__} = sub {
    open my $fh, ">>", $logfile or warn "can't open $logfile $!";
    my $date = DateTime->now->iso8601;
    print $fh "$date user[$<] @_\n";
    close $fh;
};

#
# Create the root object.
my $cui = new Curses::UI ( 
    -clear_on_exit => 1, 
    -debug => $debug,
);


# the action menu at the bottom
my $bottom_window = $cui->add(
    'w0', 'Window', 
    -border        => 1, 
    -y             => -1, 
    -height        => 3,
);
my $bottom_menu = $bottom_window->add(
    'explain', 'Label', 
    # how to change this dynamically? 
    -text => 'CTRL+Q: quit  CTRL+B: back  CTRL+S: save   CTRL+N new event ',
);

# the main event list in the first window
my $event_list_window = $cui->add(
    'event_list', 'Window',
    -title => 'Event List',
    -border       => 1, 
    -titlereverse => 0, 
    -padtop       => 2, 
    -padbottom    => 3, 
    -ipad         => 1,
);
setup_event_list();
$event_list_window->add(
    'listboxlabel', 'Label',
    -y => -1,
    -bold => 1,
    -text => "Use up/down arrows or j/k or pgup/pgdown or /search and hit <enter>",
    -width => -1,
);

# the second window to edit an event
my $Current_Event;
my $editing_event = 0;
my $event_edit_window = $cui->add(
    'event_edit', 'Window',
    -title => 'Edit Event',
    -border       => 1, 
    -titlereverse => 0, 
    -padtop       => 2, 
    -padbottom    => 3, 
    -ipad         => 1,
);

my @venues = sort { $a->vkey cmp $b->vkey } bacds::Model::Venue->load_all();
my (%venue_labels, @venue_values, %venue_position_in_list);
my $i = 0;
foreach my $venue (@venues) {
    my $vkey = $venue->vkey;
    $venue_labels{$vkey} = join ' ', "[$vkey]", $venue->hall;
    push @venue_values, $vkey;
    $venue_position_in_list{$vkey} = $i++;
}

    
# venue list
my $y = 1;
my $venue_list = $event_edit_window->add(
    undef, 'Listbox',
    -y          => $y,
    -height     => 10,
    -values     => \@venue_values,
    -labels     => \%venue_labels,
    -width      => 80,
    -border     => 1,
    -title      => "Venue",
    -vscrollbar => 1,
    -onchange   => \&select_venue,
);

#venue entry
$y += 10;
$event_edit_window->add(
    undef, 'Label',
    -y => $y,
    -text => "Venue:",
    -width => 7,
);
my $venue_label = $event_edit_window->add(
    undef, 'Label',
    -y => $y,
    -x => 8,
    #-text => "Venue:",
    -width => 20,
);

#caller entry
$y += 1;
$event_edit_window->add(
    undef, 'Label',
     -y => $y,
    -text => "Caller:",
    -width => 7,
);
my $caller_input = $event_edit_window->add(
    undef, 'TextEntry',
    -sbborder => 1,
    -y => $y,
    -x => 21,
    -width => 50,
    #-text => $Even$Event_To_Edit->leader,
);

# dance type
$y += 1;
$event_edit_window->add(
    undef, 'Label',
     -y => $y,
    -text => "Type:",
    -width => 7,
);
my $type_input = $event_edit_window->add(
    undef, 'TextEntry',
    -sbborder => 1,
    -y => $y,
    -x => 21,
    -width => 30,
);


# url
$y += 1;
$event_edit_window->add(
    undef, 'Label',
     -y => $y,
    -text => "URL:",
    -width => 7,
);
my $url_input = $event_edit_window->add(
    undef, 'TextEntry',
    -sbborder => 1,
    -y => $y,
    -x => 21,
    -width => 30,
);

# empty row
$y += 1;

# start date
$y += 1;
$event_edit_window->add(
    undef,  'Label',
    -y => $y,
     -text => 'Start Date:'
);
my $startdate_input = $event_edit_window->add( 
    'startdatelabel', 'Label', 
    -width => 10, 
    -y => $y, 
    -x => 17, 
    -text => 'none',
);

$event_edit_window->add(
    undef, 'Buttonbox',
    -y => $y,    
    -x => 28,
    -buttons => [
         { 
	   -label => "< Set date >",
	   -onpress => sub { 
	       my $label = shift()->parent->getobj('startdatelabel');
	       my $date = $label->get;
	       $date = undef if $date eq 'none';
	       my $return = $cui->calendardialog(-date => $date);
	       $label->text($return) if defined $return;
	   }
         },{
	   -label => "< Clear date >",
	   -onpress => sub {
	       my $label = shift()->parent->getobj('startdatelabel');
	       $label->text('none');
	   }
	 }
    ]
);

# end date
$y += 1;
$event_edit_window->add(
     undef,  'Label',
     -y => $y,
     -text => 'End Date (opt):'
);
my $enddate_input = $event_edit_window->add( 
    'enddatelabel', 'Label', 
    -width => 10, 
    -y => $y, 
    -x => 17, 
);

$event_edit_window->add(
    undef, 'Buttonbox',
    -y => $y,    
    -x => 28,
    -buttons => [
         { 
	   -label => "< Set date >",
	   -onpress => sub { 
	       my $label = shift()->parent->getobj('enddatelabel');
	       my $date = $label->get;
	       $date = undef if $date eq 'none';
	       my $return = $cui->calendardialog(-date => $date);
	       $label->text($return) if defined $return;
	   }
         },{
	   -label => "< Clear date >",
	   -onpress => sub {
	       my $label = shift()->parent->getobj('enddatelabel');
	       $label->text('none');
	   }
	 }
    ]
);

# band: big text box
$y += 2;
my $band_input = $event_edit_window->add(
    'band', 'TextEditor',
    -title => 'The Band',
    -wrapping => 1,
    -y => $y,
    -width => 80,
    -border => 1,
    -padbottom => 1,
    -vscrollbar => 1,
    -hscrollbar => 1,
    #-onChange => sub { },
);

sub open_edit_event_window {
    my $listbox = shift;
    my @sel = $listbox->get;
    $Current_Event = my $event = bacds::Model::Event->load(event_id => $sel[0]);
    $event_edit_window->focus;
    $venue_list->focus;
    my $pos_in_list = $venue_position_in_list{ $event->loc };
    $venue_list->set_selection();
    $caller_input->text($event->leader);
    $type_input->text($event->type);
    $url_input->text($event->url);
    $startdate_input->text($event->startday);
    $enddate_input->text($event->endday);
    $venue_label->text($event->loc);
    $band_input->text($event->band);
    $editing_event = 1;
}

sub open_create_event_window {
    my $listbox = shift;
    $event_edit_window->focus;

    $Current_Event = undef;
    $event_edit_window->focus;
    $venue_list->focus;
    $caller_input->text('');
    $type_input->text('');
    $url_input->text('');
    $startdate_input->text('');
    $enddate_input->text('');
    $venue_label->text('(select from list)');
    $band_input->text('');
    $editing_event = 1;
}

sub select_venue {
    my $listbox = shift;
    my @sel = $listbox->get;
    $venue_label->text($sel[0]);
}

sub save_event {
    return unless $editing_event;

    my $event = $Current_Event || bacds::Model::Event->new;

    if (!$startdate_input->text) {
        $cui->dialog("Missing startdate, not saving");
        return;
    }
    if (!$type_input->text) {
        $cui->dialog("Missing type, not saving");
        return;
    }
    if (!$venue_label->text or $venue_label->text =~ /select from list/) {
        $cui->dialog("Missing venue, not saving");
        return;
    }
    # allow empty caller field
    # if (!$caller_input->text) {
    #     $cui->dialog("Missing caller");
    #     return;
    # }
    if (!$band_input->text) {
        $cui->dialog("Missing band, not saving");
        return;
    }
        

    $event->startday($startdate_input->text);
    $event->endday($enddate_input->text);
    $event->type($type_input->text);
    $event->url($url_input->text);
    $event->loc($venue_label->text);
    $event->leader($caller_input->text);
    $event->band($band_input->text);

    #$event->comments(xxx);
    #$event->photo(xxx);
    #$event->performer_url(xxx);
    #$event->pacific_time(xxx);

    $event->save;

    $cui->dialog("Save complete\nPlease make the same change at https://bacds.org/dance-scheduler/");
}

sub switch_to_first_window {
    $event_list_window->focus;
    $Current_Event = undef;
    $editing_event = 0;
    setup_event_list();
}


# ----------------------------------------------------------------------
# Setup bindings and focus 
# ----------------------------------------------------------------------

# Bind <CTRL+Q> to quit.
$cui->set_binding( sub{ exit }, "\cQ" );
$cui->set_binding( \&save_event, "\cS" );
$cui->set_binding( \&switch_to_first_window, "\cB" );
$cui->set_binding( \&open_create_event_window, "\cN" );

$event_list_window->focus;



# ----------------------------------------------------------------------
# Get things rolling...
# ----------------------------------------------------------------------

$cui->mainloop;


sub setup_event_list {

    my @events = sort { $b->startday cmp $a->startday } bacds::Model::Event->load_all();

    my (%labels, @values);
    foreach my $event (@events) {
        my $event_id = $event->event_id;
        $labels{$event_id} =
             join ' ',
             "[$event_id]",
             $event->startday,
             #$event->endday # often blank
             map { $event->$_ }
             qw/
                type
                loc
                leader
                band
            /;
        push @values, $event->event_id;
    }

    state $event_list;

    if (!$event_list) {
        $event_list = $event_list_window->add(
            undef, 'Listbox',
            -y          => 1,
            -padbottom  => 2,
            -values     => \@values,
            -labels     => \%labels,
            -width      => 80,
            -border     => 1,
            -title      => "Listbox",
            -vscrollbar => 1,
            -onchange   => \&open_edit_event_window,
        );
    } else {
        $event_list->values(\@values);
        $event_list->labels(\%labels);
        $event_list->draw;
    }
}

use bacds::Model::Utils qw/csv_dir/;
use bacds::Model::Utils qw/get_dbh/;
sub check_sequence_file {

    my $stmt = 'SELECT max(event_id) FROM schedule';
    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt)
        or die $dbh->errstr;
    $sth->execute()
        or die $sth->errstr;

    my ($max_event_id) = $sth->fetchrow_array;

    # tests and zero-state
    return if ! $max_event_id;

    my $db_dir = csv_dir();
    my $lock_path = "$db_dir/schedule.lock";
    open my $fh, "<", $lock_path
        or die "can't read $lock_path $!";

    my $sequence_value = <$fh>;
    chomp $sequence_value;

    if ($max_event_id > $sequence_value) {
        die "ERROR: $lock_path says '$sequence_value', that doesn't look right.\nPlease fix it to match the max value in $db_dir/schedule\n";
    }

}
