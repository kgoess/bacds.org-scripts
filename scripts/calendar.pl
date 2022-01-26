#!/usr/bin/perl -wT
#
# calendar.pl -- print calendar of BACDS events.
#
# Nick Cuccia
# 2003-03-29
#

use strict;
use CGI qw/:standard :html3 :html4 *table *Tr/;
use CGI::Carp;
use Date::Calc qw(Today Days_in_Month Day_of_Week Month_to_Text);
use DBI;

my $cur_year;
my $cur_mon;

print header();
print start_html(
	-title => 'BACDS Calendar generator',
	-style => {
		-src => 'http://www.bacds.org/css/calendar.css'
	}
);
print h1("BACDS Events Calendar");
# year and month
($cur_year, $cur_mon) = Today();
print_tab_calendar($cur_year, $cur_mon);
print_selection_form($cur_year, $cur_mon);
print end_html();

sub print_selection_form {
	my ($yr, $mon) = @_;

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
	db_loc_lookup($yr,$mon,\%loc_hash,\@loc_val_lst);
	print td(
		popup_menu(
			-name => 'Location',
			-values => \@loc_val_lst,
			-default => $dflt_loc,
			-labels => \%loc_hash
		)
	);
	db_style_lookup($yr,$mon,\%style_hash,\@style_val_lst);
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
	db_leader_lookup($yr,$mon,\@leader_lst);
	print td(
		popup_menu(
			-name => 'Leaders',
			-values => \@leader_lst,
			-default => $dflt_leader
		)
	);
	db_muso_lookup($yr,$mon,\@band_lst);
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

sub print_tab_calendar {
	my ($cur_year, $cur_mon) = @_;

	my $cur_days_in_mon;
	my $cur_day_of_mon;
	my $cur_day_of_wk;
	my $days_in_wk = 7;
	my $dow;

	##
	## get important values for the given month
	##
	# Days in current month
	$cur_days_in_mon = Days_in_Month($cur_year, $cur_mon);
	# We're basing everything on the first day of the month
	$cur_day_of_mon = 1;
	# and the first day of the week
	$cur_day_of_wk = Day_of_Week(
		$cur_year,
		$cur_mon,
		$cur_day_of_mon
	);

	# print start of month
	print_start_of_mon($cur_mon,$cur_year);

	## If the current isn't Sunday, print a partial week;
	## otherwise, fall through and loop through full weeks.
	if (($cur_day_of_wk % $days_in_wk) != 0) {
		$dow = 0;
		while ($dow != $cur_day_of_wk) {
			print_empty($dow);
			$dow++;
		}
		while ($dow < $days_in_wk) {
			print_date(
				$dow,
				$cur_year,
				$cur_mon,
				$cur_day_of_mon
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
				print_date (
					$dow,
					$cur_year,
					$cur_mon,
					$cur_day_of_mon
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
	print td({-class => 'calendar'});
}

#
sub print_date {
	my ($dow, $cyr, $cmon, $cdom) = @_;
	my $dstr;

	print start_Tr() if ($dow == 0);
	print td({-class => 'calendar'},$cdom);
}

#
sub print_end_of_wk {
	print end_Tr();
}

#
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

########
##### Database routines -- Should modularize these
########

sub db_loc_lookup {
	my ($year, $mon, $reflochash, $refloclst) = @_;

	my $sched_qrystr;
	my $venue_qrystr;
	my $sth;
	my @loc_lst;
	my $venue;
	my $addr;
	my $city;

	## XXX -- need better way of handling this.
	my $dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');

	#
	# First, figure out what venues we're using this month
	#
	$sched_qrystr = "SELECT loc FROM schedule";
	$sched_qrystr .= " WHERE startday LIKE '" . $year . "-";
	$sched_qrystr .= "0" if ($mon < 10);
	$sched_qrystr .= $mon . "%'";
	$sched_qrystr .= " OR endday LIKE '" . $year . "-";
	$sched_qrystr .= "0" if ($mon < 10);
	$sched_qrystr .= $mon . "%'";
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
		$venue_qrystr .= " WHERE key = '" . $venue . "'";
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
	my ($year, $mon, $refstyhash, $refstylst) = @_;

	my $sched_qrystr;
	my $style_qrystr;
	my $sth;
	my @loc_lst;
	my $style;
	my $desc;

	## XXX -- need better way of handling this.
	my $dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');
	#
	# First, figure out what styles are being danced this month
	#
	$sched_qrystr = "SELECT type FROM schedule";
	$sched_qrystr .= " WHERE startday LIKE '" . $year . "-";
	$sched_qrystr .= "0" if ($mon < 10);
	$sched_qrystr .= $mon . "%'";
	$sched_qrystr .= " OR endday LIKE '" . $year . "-";
	$sched_qrystr .= "0" if ($mon < 10);
	$sched_qrystr .= $mon . "%'";
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
		$style_qrystr .= " WHERE key = '" . $style . "'";
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
	my ($year, $mon, $ldrref) = @_;

	my $qrystr;
	my $sth;
	my $ldr;
	my %ldr_hash;

	## XXX -- need better way of handling this.
	my $dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');
	#
	# First, figure out what styles are being danced this month
	#
	$qrystr = "SELECT leader FROM schedule";
	$qrystr .= " WHERE startday LIKE '" . $year . "-";
	$qrystr .= "0" if ($mon < 10);
	$qrystr .= $mon . "%'";
	$qrystr .= " OR endday LIKE '" . $year . "-";
	$qrystr .= "0" if ($mon < 10);
	$qrystr .= $mon . "%'";
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
	my ($year, $mon, $musoref) = @_;

	my $qrystr;
	my $sth;
	my $band;
	my %ldr_hash;
	my %bandhash;
	my %musohash;
	my @mlst;

	## XXX -- need better way of handling this.
	my $dbh = DBI->connect("DBI:CSV:f_dir=/www/htdocs/www.bacds.org/data;csv_eol=\n;csv_sep_char=|;csv_quote_char='",'','');
	#
	# First, figure out what styles are being danced this month
	#
	$qrystr = "SELECT band FROM schedule";
	$qrystr .= " WHERE startday LIKE '" . $year . "-";
	$qrystr .= "0" if ($mon < 10);
	$qrystr .= $mon . "%'";
	$qrystr .= " OR endday LIKE '" . $year . "-";
	$qrystr .= "0" if ($mon < 10);
	$qrystr .= $mon . "%'";
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
