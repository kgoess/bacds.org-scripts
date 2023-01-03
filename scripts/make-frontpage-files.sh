#!/bin/bash
#
# make-frontpage-files.sh
#
# This is called from cron, see "sudo crontab -u apache -e"
#
# Alan Winston
# 2008-09-09
#
basedir=${TEST_BASE_DIR-/var/www/bacds.org/public_html/}
#
# write files into the home directory
cd $basedir
# header piece
# edb 8dec08  set environment vars to eliminate error msgs
# apw 9dec08  add QUERY_STRING so that the script has something to parse.
# edb 3may20  add support for ZOOM dance type
# edb 24jul20 touch home page to update timestamp to show it's fresh data
# apw 23aug20 use zoomevents2 script to allow format flexibility.
# kmg 02Feb20 checked this script into git under /var/lib/git/bacds.org-scripts/
# kmg 02Feb20 remove both zoomevents per discussion with edb and apw, see
#             thread "Zoomevents2.pl script, content.html page, messed with
#             schedule database"
REQUEST_METHOD="" QUERY_STRING="" perl scripts/tonightheader.pl > tonight.html
#
# append today's dances to the header piece
# edb 8dec08  set environment vars to eliminate error msgs
REQUEST_METHOD="" QUERY_STRING="numdays=1&outputtype=INLINE" perl scripts/dancefinder.pl  >> tonight.html
#
# new file for 10day listing.
# edb 8dec08  set environment vars to eliminate error msgs
REQUEST_METHOD="" QUERY_STRING="numdays=10&outputtype=INLINE" perl scripts/dancefinder.pl  > 10day.html
REQUEST_METHOD="" QUERY_STRING="numdays=18&outputtype=INLINE" perl scripts/dancefinder.pl  > 18day.html
# new file for special event listings
perl scripts/specialevents.pl > specialevents.html
#
# edb 24jul20 touch home page to update timestamp to show it's fresh data
touch index.html

#
# new dbix output files
#
eval $(perl -Mlocal::lib=/var/lib/dance-scheduler)
# this dancefinder.pl is in /var/lib/dance-scheduler/bin/
# TODO: convert tonightheader.pl
REQUEST_METHOD="" QUERY_STRING="" perl scripts/tonightheader.pl > tonight-dbix.html
dancefinder.pl --days 0 >> tonight-dbix.html
dancefinder.pl --days 18 > 18day-dbix.html
dancefinder.pl --style CAMP --style SPECIAL > specialevents-dbix.html
