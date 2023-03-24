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
# these are the old csv-database scripts
#REQUEST_METHOD="" QUERY_STRING="" perl scripts/tonightheader.pl > tonight.html
#REQUEST_METHOD="" QUERY_STRING="numdays=1&outputtype=INLINE" perl scripts/dancefinder.pl  >> tonight.html
#REQUEST_METHOD="" QUERY_STRING="numdays=10&outputtype=INLINE" perl scripts/dancefinder.pl  > 10day.html
#REQUEST_METHOD="" QUERY_STRING="numdays=18&outputtype=INLINE" perl scripts/dancefinder.pl  > 18day.html
#perl scripts/specialevents.pl > specialevents.html

# touch home page to update timestamp to show it's fresh data
touch index.html

#
# new dbix output files
#
eval $(perl -Mlocal::lib=/var/lib/dance-scheduler)
# this dancefinder.pl is in /var/lib/dance-scheduler/bin/
# using a tempfile-two-step otherwise during the time it takes the script to
# run the users are looking at an empty file with no content
#REQUEST_METHOD="" QUERY_STRING="" perl scripts/tonightheader.pl > tonight-dbix.html
tonightheader.pl > dancefinder-temp.html && cat dancefinder-temp.html > tonight-dbix.html
dancefinder.pl --days 0 > dancefinder-temp.html && cat dancefinder-temp.html >> tonight-dbix.html
dancefinder.pl --days 18 > dancefinder-temp.html && cat dancefinder-temp.html > 18day-dbix.html
dancefinder.pl \
    --style CAMP \
    --style SPECIAL \
    --no-highlight-specials \
    > dancefinder-temp.html \
    && cat dancefinder-temp.html > specialevents-dbix.html
rm dancefinder-temp.html
