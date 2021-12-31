
help:
	@echo "usage: make (install|test)"

install:
	cp bin/serieslists.pl /var/www/bacds.org/public_html/scripts/serieslists.pl	
	cp bin/dancefinder.pl /var/www/bacds.org/public_html/scripts/dancefinder.pl	

test:
	prove t
