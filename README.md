bacds version 0.01
==================

scripts from the bacds.org server

INSTALLATION

To install this module and all the scripts type the following:

    perl Makefile.PL
    make
    make test
    sudo make install

(You can also do "make diff-with-prod" before "make install" to see what the
changes will be.)

For some reason the "make install" is installing any vim .swp files in
scripts/. Doesn't happen for lib/. Not sure how to fix that.
Watch for them in the "make install" and remove them yourself if it happens.

COPYRIGHT AND LICENCE

Copyright (C) 2022 by Kevin M. Goess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.


