
help:
	@echo "usage: make (install|test)"

install:
	cp scripts/*.pl /var/www/bacds.org/public_html/scripts/
	cp cgi-bin/dancefinder.cgi /var/www/bacds.org/cgi-bin/dancefinder.cgi

test:
	prove t
