
help:
	@echo "usage: make (install|test)"

install:
	cp scripts/serieslists.pl /var/www/bacds.org/public_html/scripts/serieslists.pl	
	cp scripts/dancefinder.pl /var/www/bacds.org/public_html/scripts/dancefinder.pl	
	cp cgi-bin/dancefinder.cgi /var/www/bacds.org/cgi-bin/dancefinder.cgi

test:
	prove t
