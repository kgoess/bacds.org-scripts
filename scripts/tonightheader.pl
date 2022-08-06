#!/usr/bin/perl -w
##
## Determine whether there are any dances tonight (today's date)
## and emit an H1 header followed by a div class=tonight if there are;
## if not, no header, and a tagless div.
##
## current usage:
##
## public_html/scripts/make-frontpage-files.sh:REQUEST_METHOD="" QUERY_STRING="" perl scripts/tonightheader.pl > tonight.html
## public_html/scripts/make-tonight-file.sh:perl scripts/tonightheader.pl > tonight.html
##
## This script doesn't do anything with any arguments.

use strict;
use CGI;

use bacds::Model::Event;

my $meta_file = '/var/www/bacds.org/public_html/shared/meta-tags.html';

my $numrows = bacds::Model::Event->get_count_for_today();

my $plural = $numrows > 1 ? "s" : "";

print <<ENDHTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xthml1-strict.dtd">
<html>
<head>
<title>Dance tonight</title>
ENDHTML
	open(METAFILE,"<$meta_file") || die "can't open $meta_file: $!";
	print while <METAFILE>;
	close(METAFILE);
	print <<ENDHTML;
<link rel="stylesheet" title="base" type="text/css" href="/css/base.css" />
</head>
<body index="scriptoutput">
<h1>
ENDHTML
print "\n</h1>\n";

if ($numrows) {
    print "<h2>Today's Dance$plural:</h2>\n";
    # look for "div.tonight" style in /css/base.css for styling
    print '<div class="tonight">', "\n";
} else {
    print '<div class="tonight">', "\n";
    print "<h2>No dances tonight</h2>\n";
}    
    
print <<ENDHTML;
</body>
</html>
ENDHTML

