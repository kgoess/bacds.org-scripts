
help:
	@echo "usage: make (install|test)"

install:
	cp scripts/*.pl /var/www/bacds.org/public_html/scripts/
	cp cgi-bin/*.cgi /var/www/bacds.org/cgi-bin/

test:
	prove -r -Ilib t
