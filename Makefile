
help:
	usage: make (install|test)

install:
	cp bin/serieslists.pl /var/www/bacds.org/public_html/scripts/serieslists.pl	

test:
	prove t
