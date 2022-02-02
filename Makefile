
help:
	@echo "usage: make (install|test|diff-with-prod)"
	@echo .
	@echo "(use "make diff-with-prod" before "make install" to see what changes will be wrought)"

install:
	cp scripts/*.pl /var/www/bacds.org/public_html/scripts/
	cp cgi-bin/*.cgi /var/www/bacds.org/cgi-bin/

test:
	prove -r -Ilib t

diff-with-prod:
	for f in scripts/*.pl ; do \
		diff -u $$f /var/www/bacds.org/public_html/scripts/$$(basename $$f); \
	done
	for f in cgi-bin/*.cgi ; do \
		diff -u $$f /var/www/bacds.org/cgi-bin/$$(basename $$f); \
	done
