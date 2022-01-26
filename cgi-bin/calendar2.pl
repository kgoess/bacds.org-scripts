#!/usr/bin/perl
#
# calendar.pl -- print calendar of BACDS events.
#
# Nick Cuccia
# 2003-04-27
#
# 2020-11-24 edb comments: ignore lines starting with '#'
#
## This file is being tracked in git. DON'T MAKE IN-PLACE EDITS AND
## EXPECT THEM TO SURVIVE.
## To clone the repo, add yourself to the "git" group
#  "sudo usermod -a -G git <username>" 
## and then do "git clone /var/lib/git/bacds.org-scripts/"

use strict;
use warnings;
use CGI qw/:standard :html3 :html4 *table *Tr *td *div/;
use CGI::Carp;
use Date::Calc qw(Today Days_in_Month Day_of_Week Month_to_Text);
use DBI;

my $TableChoice;

my $CSV_DIR = $ENV{TEST_CSV_DIR} || '/var/www/bacds.org/public_html/data';
my $TEST_TODAY = $ENV{TEST_TODAY};

sub db_venue_lookup {
	my ($syear, $smon, $eyear, $emon, $refloclst) = @_;

	my $sched_qrystr;
	my $venue_qrystr;
	my $sth;
	my @loc_lst;
	my $venue;
	my $hall;
	my $addr;
	my $city;
	my $comment;
	my %lochash;

	my $dbh = get_dbh();
    
	#
	# First, figure out what venues we're using this month
	#
	$sched_qrystr = "SELECT loc FROM $TableChoice";
	$sched_qrystr .= " WHERE startday LIKE '" . $syear . "-";
	$sched_qrystr .= sprintf "%02d", $smon;
	$sched_qrystr .= "%'";
	$sched_qrystr .= " OR endday LIKE '" . $eyear . "-";
	$sched_qrystr .= sprintf "%02d", $emon;
	$sched_qrystr .= "%'";
	$sth = $dbh->prepare($sched_qrystr);
	$sth->execute;
	while (($venue) = $sth->fetchrow_array()) {
		$lochash{$venue} = "" if ($venue ne "");
	}
	#
	# Next, get the descriptions for them.
	#
	foreach $venue (keys %lochash) {
		$venue_qrystr = "SELECT hall, address, city, comment FROM venue";
		$venue_qrystr .= " WHERE vkey = '" . $venue . "'";
		$sth = $dbh->prepare($venue_qrystr);
		$sth->execute;
		while (($hall,$addr,$city,$comment) = $sth->fetchrow_array()) {
			push @$refloclst, join('|',$venue,$hall,$addr,$city,$comment);
		}
	}
	sort @$refloclst;
}

sub print_venues {
	my ($start_yr, $start_mon, $end_yr, $end_mon) = @_;
	my $venue;

	print start_table();
	my @loc_list;
	db_venue_lookup(
			$start_yr,
			$start_mon,
			$end_yr,
			$end_mon,
			\@loc_list
		     );
	print start_Tr;
	print th({class => 'callisting'},'VENUE');
	print th({class => 'callisting'},'NAME');
	print th({class => 'callisting'},'ADDRESS');
	print th({class => 'callisting'},'CITY');
	print end_Tr;
	foreach $venue (sort @loc_list) {
		my ($key,$name,$addr,$city,$cmts);
		($key,$name,$addr,$city,$cmts) = split('\|',$venue);
		print start_Tr;
		print td({-class => 'callisting'},$key);
		print td({-class => 'callisting'},$name);
		print td({-class => 'callisting'},$addr);
		print td({-class => 'callisting'},$city);
		print end_Tr;
		if ($cmts ne "") {
			print start_Tr;
			print td({-class => 'calcomment'});
			print td({-class => 'calcomment', -colspan => 4},em($cmts));
			print end_Tr;
		}
	}
	print end_table();
}

sub print_schedule {
	my ($start_yr, $start_mon, $end_yr, $end_mon, $schedref) = @_;
	my $event;
	my %taghash;
	my $div_start;

	$div_start = 0;


	my ($tyear, $tmon, $tday) = my_today();

	print start_table();
	print start_Tr;
	print th({class => 'caltitle'},'DATE(S)');
	print th({class => 'caltitle'},'STYLE');
	print th({class => 'caltitle'},'LOCATION');
	print th({class => 'caltitle'},'CALLER(S)<br>TEACHER(S)');
	print th({class => 'caltitle', -align=>'center'},'MUSICIANS');
	print end_Tr;
	foreach $event (@$schedref) {
		my $start;
		($start) = split('\|',$event);
		$taghash{$start} = 0;
	}
	foreach $event (@$schedref) {
		my ($stday,$endday,$typ,$loc,$ldr,$band,$cmts);
		my ($tsyr, $tsmon, $tsday);
		my ($teyr, $temon, $teday);
		my ($ttemon, $ttsmon);
		my $txtdate;
		($stday,$endday,$typ,$loc,$ldr,$band,$cmts) = split('\|',$event);
		($tsyr,$tsmon,$tsday) = split('-',$stday);
		$ttsmon = Month_to_Text($tsmon);
		$txtdate = $ttsmon . '&nbsp;' . $tsday;
		$tsday =~ s/^0//;
		if ($endday ne '') {
			($teyr,$temon,$teday) = split('-',$endday);
			$ttemon = Month_to_Text($temon);
			$txtdate .= '&nbsp;to&nbsp;' . $ttemon . '&nbsp;' . $teday;
		}
		if ($tsyr == $tyear && $tsmon == $tmon && $tsday == $tday) {
			if ($div_start == 0) {
				print start_div({-class => 'tonight'});
				$div_start = 1;
			}
		} else {
			if ($div_start == 1) {
				print end_div;
				$div_start = 0;
			}
		}
		print start_Tr;
		print start_td({-class => 'callisting'});
		print a({-name => $stday},'')
		    if ($taghash{$stday}++ == 0);
		print $txtdate;
		print end_td;
		print td({-class => 'callisting'},$typ);
		print td({-class => 'callisting'},$loc);
		# edb 30may2010: tighten up comments in listing
		if (0 && $cmts) {
			print td({-class => 'callisting', -rowspan=>2},$ldr);
			print td({-class => 'callisting', -rowspan=>2},$band);
		} else {
			print td({-class => 'callisting'},$ldr);
			print td({-class => 'callisting'},$band);
		}
		print end_Tr;
		# edb 18jun2020: indent comments to tie to listing
		if ($cmts) {
			print start_Tr( {-class=>'calcomment'} );
			print td({-class => 'calcomment'});
			print td({-class => 'calcomment', -colspan => 4},em($cmts));
			print end_Tr;
		}
	}
	print end_table();
}

sub print_selection_form {
	my ($start_yr, $start_mon, $end_yr, $end_mon) = @_;

	my $dflt_loc = "NON";
	my $dflt_style = "NON";
	my $dflt_leader = "Select a Caller";
     	my $dflt_band = "Select a Band or Musician";
	print start_form;
	print start_table();
	print start_Tr;
	my %loc_hash;
	my @loc_val_lst;
	my %style_hash;
	my @style_val_lst;
	my @leader_lst;
	my @band_lst;
	db_loc_lookup(
			$start_yr,
			$start_mon,
			$end_yr,
			$end_mon,
			\%loc_hash,
			\@loc_val_lst
		     );
	print td(
		popup_menu(
			-name => 'Location',
			-values => \@loc_val_lst,
			-default => $dflt_loc,
			-labels => \%loc_hash
		)
	);
	db_style_lookup(
			$start_yr,
			$start_mon,
			$end_yr,
			$end_mon,
			\%style_hash,
			\@style_val_lst
		       );
	print td(
		popup_menu(
			-name => 'Style',
			-values => \@style_val_lst,
			-default => $dflt_style,
			-labels => \%style_hash
		)
	);
	print end_Tr;
	print start_Tr;
	db_leader_lookup(
			$start_yr,
			$start_mon,
			$end_yr,
			$end_mon,
			\@leader_lst
			);
	print td(
		popup_menu(
			-name => 'Leaders',
			-values => \@leader_lst,
			-default => $dflt_leader
		)
	);
	db_muso_lookup(
			$start_yr,
			$start_mon,
			$start_yr,
			$start_mon,
			\@band_lst
		      );
	print td(
		popup_menu(
			-name => 'Bands_Musos',
			-values => \@band_lst,
			-default => $dflt_band
		)
	);
	print end_Tr;
	print end_table();
	print end_form;
}

sub print_start_of_mon {
	my ($mon, $yr) = @_;

	print start_table(-class => 'calendar');
	print start_Tr();
	print th({
			-colspan => 7,
			-class => 'calendar_title'
		 }, Month_to_Text($mon) . ' ' . $yr);
	print end_Tr();
	print start_Tr();
	print th({-class => 'calendar'},"Su");
	print th({-class => 'calendar'},"M");
	print th({-class => 'calendar'},"Tu");
	print th({-class => 'calendar'},"W");
	print th({-class => 'calendar'},"Th");
	print th({-class => 'calendar'},"F");
	print th({-class => 'calendar'},"Sa");
	print end_Tr();
}

#
sub print_end_of_mon {
	print end_Tr();
	print end_table();
}

sub print_date {
	my ($dow, $cyr, $cmon, $cdom, $datelnk) = @_;
	my $dstr;

	my ($tyear, $tmon, $tday) = my_today();

	print start_Tr() if ($dow == 0);
	print start_td({-class => 'calendar'});
	if ($cyr == $tyear && $cmon == $tmon && $cdom == $tday) {
		print start_div({-class => 'tonight'});
	}
	print a({-href => $datelnk},$cdom) if ($datelnk ne "");
	print $cdom if ($datelnk eq "");
	if ($cyr == $tyear && $cmon == $tmon && $cdom == $tday) {
		print end_div;
	}
	print end_td;
}

sub print_tab_calendar {
	my ($cur_start_year, $cur_start_mon,
	    $cur_end_year, $cur_end_mon, $schedref) = @_;

	my $cur_days_in_mon;
	my $cur_day_of_mon;
	my $cur_day_of_wk;
	my $days_in_wk = 7;
	my $dow;
	my $datelnk;
	my $datestr;
	my %taghash;
	my $event;

	foreach $event (@$schedref) {
		my $start;
		($start) = split('\|',$event);
		$taghash{$start} = 'YES';
	}

	##
	## get important values for the given month
	##
	# Days in current month
	$cur_days_in_mon = Days_in_Month($cur_start_year, $cur_start_mon);
	# We're basing everything on the first day of the month
	$cur_day_of_mon = 1;
	# and the first day of the week
	$cur_day_of_wk = Day_of_Week(
		$cur_start_year,
		$cur_start_mon,
		$cur_day_of_mon
	);

	# print start of month
	print_start_of_mon($cur_start_mon,$cur_start_year);

	## If the current isn't Sunday, print a partial week;
	## otherwise, fall through and loop through full weeks.
	if (($cur_day_of_wk % $days_in_wk) != 0) {
		$dow = 0;
		while ($dow != $cur_day_of_wk) {
			print_empty($dow);
			$dow++;
		}
		while ($dow < $days_in_wk) {
			my $datekey;
		        my $datekey2;  # make resilience against days <10
			$datelnk = '';
			$datekey =  $cur_start_year . '-';
			$datekey .= '0' if ($cur_start_mon < 10);
			$datekey .= $cur_start_mon . '-';
		        $datekey2 = $datekey;
			$datekey .= '0' if ($cur_day_of_mon < 10);
			$datekey .= $cur_day_of_mon;
		        $datekey2 .= $cur_day_of_mon;
			$datelnk =  '#' . $datekey if ($taghash{$datekey}||'' eq 'YES');
			$datelnk =  '#' . $datekey2 if ($taghash{$datekey2}||'' eq 'YES');
			print_date(
				$dow,
				$cur_start_year,
				$cur_start_mon,
				$cur_day_of_mon,
				$datelnk
			);
			$dow++;
			$cur_day_of_mon++;
		}
		print_end_of_wk();
	}

	##
	## and print rest of the month
	##
	while ($cur_day_of_mon <= $cur_days_in_mon) {
		$dow = 0;
		while ($dow < $days_in_wk) {
			if ($cur_day_of_mon <= $cur_days_in_mon) {
				my $datekey;
				$datelnk = '';
				$datekey =  $cur_start_year . '-';
				$datekey .= '0' if ($cur_start_mon < 10);
				$datekey .= $cur_start_mon . '-';
				$datekey .= '0' if ($cur_day_of_mon < 10);
				$datekey .= $cur_day_of_mon;
				$datelnk =  '#' . $datekey if ($datekey && $taghash{$datekey} && $taghash{$datekey} eq 'YES');
				print_date (
					$dow,
					$cur_start_year,
					$cur_start_mon,
					$cur_day_of_mon,
					$datelnk
				);
			}
			$dow++;
			$cur_day_of_mon++;
		}
		print_end_of_wk();
	}
	print_end_of_mon();
}

#
sub print_empty {
	my ($dow) = @_;

	print start_Tr() if ($dow == 0);
	print td({-class => 'calendar'},'  ');
}


#
sub print_end_of_wk {
	print end_Tr();
}

#

########
##### Database routines -- Should modularize these
########

sub db_loc_lookup {
	my ($syear, $smon, $eyear, $emon, $reflochash, $refloclst) = @_;

	my $sched_qrystr;
	my $venue_qrystr;
	my $sth;
	my @loc_lst;
	my $venue;
	my $addr;
	my $city;
    
	my $dbh = get_dbh();

	#
	# First, figure out what venues we're using this month
	#
	$sched_qrystr = "SELECT loc FROM $TableChoice";
	$sched_qrystr .= " WHERE startday LIKE '" . $syear . "-";
	$sched_qrystr .= sprintf "%02d", $smon;
	$sched_qrystr .= "%'";
	$sched_qrystr .= " OR endday LIKE '" . $eyear . "-";
	$sched_qrystr .= sprintf "%02d", $emon;
	$sched_qrystr .= "%'";
	$sth = $dbh->prepare($sched_qrystr);
	$sth->execute;
	while (($venue) = $sth->fetchrow_array()) {
		$reflochash->{$venue} = "" if ($venue ne "");
	}
	#
	# Next, get the descriptions for them.
	#
	foreach $venue (keys %$reflochash) {
		$venue_qrystr = "SELECT hall, city FROM venue";
		$venue_qrystr .= " WHERE vkey = '" . $venue . "'";
		$sth = $dbh->prepare($venue_qrystr);
		$sth->execute;
		while (($addr,$city) = $sth->fetchrow_array()) {
			$reflochash->{$venue} = $addr . ', ' . $city if (($addr ne "") || ($city ne ""));
		}
	}
	#
	# and create a sorted option list
	#
	@$refloclst = "NON";
	push @$refloclst, sort keys %$reflochash;
	#
	# and add a bogus value as a 'get venue' placeholder
	#
	$reflochash->{"NON"} = "Select a Venue";
}

sub db_style_lookup {
	my ($syear, $smon, $eyear, $emon, $refstyhash, $refstylst) = @_;

	my $sched_qrystr;
	my $style_qrystr;
	my $sth;
	my @loc_lst;
	my $style;
	my $desc;

	my $dbh = get_dbh();
	#
	# First, figure out what styles are being danced this month
	#
	$sched_qrystr = "SELECT type FROM $TableChoice";
	$sched_qrystr .= " WHERE startday LIKE '" . $syear . "-";
	$sched_qrystr .= sprintf "%02d", $smon;
	$sched_qrystr .= "%'";
	$sched_qrystr .= " OR endday LIKE '" . $eyear . "-";
	$sched_qrystr .= sprintf "%02d", $emon;
	$sched_qrystr .= "%'";
	$sth = $dbh->prepare($sched_qrystr);
	$sth->execute;
	while (($style) = $sth->fetchrow_array()) {
		$refstyhash->{$style} = "" if (($style !~ '/') && ($style !~ ' and ') && ($style ne ""));
		if ($style =~ '/') {
			my $item;
			my @lst = split('/',$style);
			foreach $item (@lst) {
				$refstyhash->{$item} = "" if ($item ne "");
			}
		}
		if ($style =~ ' and ') {
			my $item;
			my @lst = split(' and ',$style);
			foreach $item (@lst) {
				$refstyhash->{$item} = "" if ($item ne "");
			}
		}
	}
	#
	# Next, get the descriptions for them.
	#
	foreach $style (keys %$refstyhash) {
		$style_qrystr = "SELECT type FROM style";
		$style_qrystr .= " WHERE skey = '" . $style . "'";
		$sth = $dbh->prepare($style_qrystr);
		$sth->execute;
		while (($desc) = $sth->fetchrow_array()) {
			$refstyhash->{$style} = $desc if ($desc ne "");
		}
	}
	#
	# and create a sorted option list
	#
	@$refstylst = "NON";
	push @$refstylst, sort keys %$refstyhash;
	#
	# and add a bogus value as a 'get style' placeholder
	#
	$refstyhash->{"NON"} = "Select a Dance Style";
}

sub db_leader_lookup {
	my ($syear, $smon, $eyear, $emon, $ldrref) = @_;

	my $qrystr;
	my $sth;
	my $ldr;
	my %ldr_hash;

	my $dbh = get_dbh();
	#
	# First, figure out what styles are being danced this month
	#
	$qrystr = "SELECT leader FROM $TableChoice";
	$qrystr .= " WHERE startday LIKE '" . $syear . "-";
	$qrystr .= sprintf "%02d", $smon;
	$qrystr .= "%'";
	$qrystr .= " OR endday LIKE '" . $eyear . "-";
	$qrystr .= sprintf "%02d", $emon;
	$qrystr .= "%'";
	$sth = $dbh->prepare($qrystr);
	$sth->execute;
	while (($ldr) = $sth->fetchrow_array()) {
		if ($ldr =~ ', ') {
			my $item;
			foreach $item (split(', ',$ldr)) {
				if ($item =~ ' \[') {
					($item) = split(' \[',$item);
				}
				$ldr_hash{$item} = "" if (($item ne "") && ($item !~ /[Ff]riend/) && ($item !~ /[Ff]riends$/));
			}
		} else {
			if ($ldr =~ ' \[') {
				($ldr) = split(' \[',$ldr);
			}
			$ldr_hash{$ldr} = "" if (($ldr ne "") && ($ldr !~ /[Ff]riends$/) && ($ldr !~ /[Ff]riend$/));
		}
	}
	# insert an option holder
	push @$ldrref, "Select a Caller";
	push @$ldrref, sort keys %ldr_hash;
}

sub db_muso_lookup {
	my ($syear, $smon, $eyear, $emon, $musoref) = @_;

	my $qrystr;
	my $sth;
	my $band;
	my %ldr_hash;
	my %bandhash;
	my %musohash;
	my @mlst;

	my $dbh = get_dbh();
	#
	# First, figure out what styles are being danced this month
	#
	$qrystr = "SELECT band FROM $TableChoice";
	$qrystr .= " WHERE startday LIKE '" . $syear . "-";
	$qrystr .= sprintf "%02d", $smon;
	$qrystr .= "%'";
	$qrystr .= " OR endday LIKE '" . $eyear . "-";
	$qrystr .= sprintf "%02d", $emon;
	$qrystr .= "%'";
	$sth = $dbh->prepare($qrystr);
	$sth->execute;
	while (($band) = $sth->fetchrow_array()) {
		my $guest = "";
		my $mstr = "";
		my $bandname = "";
		$_ = $band;
		s/ \[[^\]]+\]//g;			# Remove location
		s/ with /, /g;				# ' with ' same as ', ' 
		s/ and [Ff]riend[s]*//g;		# remove 'and Friend[s]'
		s/, [Ff]riend[s]*//g;			# remove 'and Friend[s]'
		s/[Oo]pen [Bb]and led by //;		# remove "Open Band"
		s/, and /, /;				# ' and ' same as ', '
		s/ and /, /;				# ' and ' same as ', '
		s/TBA//;				# remove "TBA"
		$band = $_;
		#
		# We've removed and cleaned up the cruft.  Now let's try to 
		#  parse out the goodies.
		#
		# At this point, we have one of:
		#
		#	muso, muso, muso, ...
		#	band (muso ...)
		#	band (muso ...), guest
		$mstr = $_;
		($bandname,$mstr,$guest) = /(.+) \((.+)\), (.+)/ if /\),/;
		($bandname,$mstr) = /(.+) \((.+)\)/ if /\)$/;
		$mstr = $_ if ! /\)/;
#	print "Parsed line:  ";
#	print "bandname=$bandname	" if $bandname;
#	print "mstr=$mstr	" if $mstr;
#	print "guest=$guest	" if $guest;
#	print "\n";
		#
		# We should be parsed now.  Now build our lists.
		#
		@mlst = split(/, /,$mstr);
		my $i;
		foreach $i (@mlst) {
			$musohash{$i} = $i if ! $musohash{$i};
		}
		$bandhash{$bandname} = $bandname if $bandname;
		$musohash{$guest} = $guest if ($guest && ! $musohash{$guest});
	}
	#
	# Manually insert open band
	#
	$bandhash{"Open Band"} = "Open Band";
	# insert an option holder
	push @$musoref, "Select a Band or Musician";
	# and load up the array
	push @$musoref, sort keys %bandhash;
	push @$musoref, "";
	push @$musoref, sort keys %musohash;
}

sub db_sched_lookup {
	my ($syear, $smon, $eyear, $emon, $schedref) = @_;

	my $qrystr;
	my $sth;
	my ($stday, $endday, $typ, $loc, $ldr, $band, $cmts);
	my @mlst;

	my $dbh = get_dbh();
	#
	# First, figure out what dances are being danced this month
	$qrystr = "SELECT ".
     "startday, endday, type, loc, leader, band, comments FROM $TableChoice";
	$qrystr .= " WHERE startday LIKE '" . $syear . "-";
	$qrystr .= sprintf "%02d", $smon;
	$qrystr .= "%'";
	$qrystr .= " OR endday LIKE '" . $eyear . "-";
	$qrystr .= sprintf "%02d", $emon;
	$qrystr .= "%'";
	$sth = $dbh->prepare($qrystr);
	$sth->execute;
	while (($stday,$endday,$typ,$loc,$ldr,$band,$cmts) = $sth->fetchrow_array()) {
		if ($cmts) {
		    $cmts =~ s/<q>/"/g;
		    push @$schedref, join('|',$stday,$endday,$typ,$loc,$ldr,$band,$cmts);
		} else {
		    push @$schedref, join('|',$stday,$endday,$typ,$loc,$ldr,$band);
		}
	}
}

sub main {

	my $base_url = url(-absolute => 1);

	my @sched;

	print header();

	my ($cur_start_year, $cur_start_mon) = my_today();
	my ($cur_end_year, $cur_end_mon) = my_today();

	$TableChoice = 'schedule';

	if ($base_url =~ /\/calendars\//) {
			my @url_parts = split(/\//,$base_url);
			if ($url_parts[1] eq "calendars") {
				my $url_yr = $url_parts[2];
				my $url_mon = $url_parts[3];
				if ($url_mon =~ /^0/) {
					$_ = $url_mon;
					s/^0//;
					$url_mon = $_;
				}
				if ($url_yr eq "current") {
					($cur_start_year, $cur_start_mon) = my_today();
					($cur_end_year, $cur_end_mon) = my_today();
				} else {
						if ($url_yr < $cur_start_year) {
						  $TableChoice = 'schedule'.$url_yr;
					}
						
					$cur_start_year = $url_yr;
					$cur_end_year = $url_yr;
					$cur_start_mon = $url_mon;
					$cur_end_mon = $url_mon;
					
				}
				   } else {
				($cur_start_year, $cur_start_mon) = my_today();
				($cur_end_year, $cur_end_mon) = my_today();
			}
		}

		print start_html(
				-title => 'BACDS Calendar generator',
			-style => {
				-src => '/css/calendar.css'
			}
		);
		print h1("BACDS Events Calendar");
		#print p("Unless otherwise stated, admission prices are:");
		#print ul(
		#	li("\$9 for weeknight dances"),
		#	li("\$10 for weekend (Friday, Saturday, Sunday) evening dances")
		#);
		#print p("Student prices are:");
		#print ul(
		#	li("\$7 for weeknight dances"),
		#	li("\$8 for weekend dances")
		#);
		#print p("Card-carrying members of BACDS, CDSS, or CDSS affiliate organizations are entitled to a \$2 discount on the above prices.");


		db_sched_lookup(
			$cur_start_year,
			$cur_start_mon,
			$cur_end_year,
			$cur_end_mon,
			\@sched
		);

		print_tab_calendar(
					$cur_start_year,
					$cur_start_mon,
					$cur_end_year,
					$cur_end_mon,
					\@sched
				  );
		print h1("Schedule of Events");
		print_schedule(
					$cur_start_year,
					$cur_start_mon,
					$cur_end_year,
					$cur_end_mon,
					\@sched
				  );
		print h1("Dance Venues");
		print_venues(
					$cur_start_year,
					$cur_start_mon,
					$cur_end_year,
					$cur_end_mon
				  );
		#print_selection_form(
		#			$cur_start_year,
		#			$cur_start_mon,
		#			$cur_end_year,
		#			$cur_end_mon
		#		    );
		print end_html();

}

sub my_today {
	my ($tyear, $tmon, $tday) =
		$TEST_TODAY
		? split '-', $TEST_TODAY
		: Today();
	return $tyear, $tmon, $tday;
}

sub get_dbh {
	return DBI->connect(
		qq[DBI:CSV:f_dir=$CSV_DIR;csv_eol=\n;csv_sep_char=|;csv_quote_char=\\], '', ''
	);
}


main();
