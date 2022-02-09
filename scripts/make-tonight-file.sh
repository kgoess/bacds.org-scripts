#!/bin/sh
#
# make-tonight-file.sh
#
# Alan Winston
# 2008-09-09
#
basedir="/var/www/bacds.org/public_html/"

cd $basedir
perl scripts/tonightheader.pl > tonight.html
perl scripts/dancefinder.pl numdays=1 outputtype=INLINE >> tonight.html
