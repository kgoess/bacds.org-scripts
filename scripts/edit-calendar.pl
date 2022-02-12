
use 5.16.0;
use warnings;

use Curses;
use Curses::UI;
use Data::Dump qw/dump/;
use File::Basename;

use bacds::Model::Event;
use bacds::Model::Venue;

my $debug = 0;
$SIG{__DIE__} = sub {
    open my $fh, ">", basename "$0.log";
    print $fh @_, "\n";
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

#venue
$event_edit_window->add(
    undef, 'Label',
     -y => -20,
    -text => "Venue:",
    -width => 7,
);
my $venue_label = $event_edit_window->add(
    undef, 'Label',
    -y => -20,
    -x => 8,
    #-text => "Venue:",
    -width => 20,
);

#caller
$event_edit_window->add(
    undef, 'Label',
     -y => -19,
    -text => "Caller:",
    -width => 7,
);
my $caller_input = $event_edit_window->add(
    undef, 'TextEntry',
    -sbborder => 1,
    -y => -19,
    -x => 21,
    -width => 50,
    #-text => $Even$Event_To_Edit->leader,
);

# dance type
$event_edit_window->add(
    undef, 'Label',
     -y => -18,
    -text => "Type:",
    -width => 7,
);
my $type_input = $event_edit_window->add(
    undef, 'TextEntry',
    -sbborder => 1,
    -y => -18,
    -x => 21,
    -width => 30,
);

# start date
$event_edit_window->add(
    undef,  'Label',
    -y => -16,
     -text => 'Start Date:'
);
my $startdate_input = $event_edit_window->add( 
    'startdatelabel', 'Label', 
    -width => 10, 
    -y => -16, 
    -x => 12, 
    -text => 'none',
);

$event_edit_window->add(
    undef, 'Buttonbox',
    -y => -16,    
    -x => 23,
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
$event_edit_window->add(
     undef,  'Label',
     -y => -15,
     -text => 'End Date:'
);
my $enddate_input = $event_edit_window->add( 
    'enddatelabel', 'Label', 
    -width => 10, 
    -y => -15, 
    -x => 12, 
    -text => 'none',
);

$event_edit_window->add(
    undef, 'Buttonbox',
    -y => -15,    
    -x => 23,
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
my $band_input = $event_edit_window->add(
    'band', 'TextEditor',
    -title => 'The Band',
    -wrapping => 1,
    -y => 16,
    -width => 80,
    -border => 1,
    -padbottom => 1,
    -vscrollbar => 1,
    -hscrollbar => 1,
    #-onChange => sub { },
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

    
my $venue_list = $event_edit_window->add(
    undef, 'Listbox',
    -y          => 1,
    -padbottom  => 20,
    -values     => \@venue_values,
    -labels     => \%venue_labels,
    -width      => 80,
    -border     => 1,
    -title      => "Venue",
    -vscrollbar => 1,
    -onchange   => \&select_venue,
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

    $event->startday($startdate_input->text);
    $event->endday($enddate_input->text);
    $event->type($type_input->text);
    $event->loc($venue_label->text);
    $event->leader($caller_input->text);
    $event->band($band_input->text);

    #$event->comments(xxx);
    #$event->url(xxx);
    #$event->photo(xxx);
    #$event->performer_url(xxx);
    #$event->pacific_time(xxx);

    $event->save;

    $cui->dialog("Save complete");
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
