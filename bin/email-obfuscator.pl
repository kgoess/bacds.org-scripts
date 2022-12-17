#!/usr/bin/perl

=head1 NAME

email-obfuscator.pl - generates encrypted mailto: links in a javascript include

=head1 SYNOPSIS

 email-obfuscator.pl [options]  > getSignature.js

 <script src="http://your.domain.com/getSignature.js">
 </script>


If the linktext isn't provided, the mailto will be used in its place.

 e.g. 
   email-obfuscator.pl --email 'Bob Jones <bob@foo.com>' --do-mailto \
                        --linktext "Bob's Email"   > /srv/www/getSignature.js
   email-obfuscator.pl --email 'Bob Jones <bob@foo.com>' > /srv/www/getSignature.js

 Options:
   --email        the email address
   --do-mailto    whether you want it wrapped in an "<a href=mailto:"
   --linktext     for a mailto link, if you want something besides the email
                  address to display
   -h|--help      brief help message
   -m|--man       full man page
   -v|--verbose
   -V|--version

=head1 DESCRIPTION

See Tim Williams' discussion on the "How and Why of obfuscating your address"
at http://www.u.arizona.edu/~trw/spam/index.htm [dead link]. There he proposes
the idea of converting your email address into a seemingly random string of
characters using a simple substitution cipher, using a <script>..</script>
block. 

The advantages to this approach over a verbatim C<mailto:> link are that
spambots using simple regular expression searching for stuff like
C</[a-z._-]+@[a-z._-].(com|net|org)/i> won't find it. Spambots have a lot of
work to do and it's unlikely that they're going to parse and run javascript
hoping to find an email address.  They might conceivably convert HTML character
entities or character codes, which is why this method is preferred for the
truly paranoid.

My method is an expansion on Tim Williams' idea in that instead of putting the
obfuscation into a <script>..</script>, it uses a javascript include to pull in
the obfuscation code.  

So you can have a C<mailto:> link on your page by adding this to your html, which
looks like anything I<but> a C<mailto:> link:

 <script language="JavaScript" src="https://your.domain.com/getSignature.js">
 </script>

That has the advantage of keeping your HTML files cleaner, and of adding one
more step to hide from the spambots, that of their having to fetch an additional
file which isn't even HTML.

This C<email-obfuscator.pl> script generates output which looks like this:

  coded = "XKA 2. tKN4r ZAKAoMKN4r.3KCn"
  codedlt = "W9Mp WZ 9a fcfNmcTZD.qcW"

  key = "R>jB5LiVpYwI1<btzeGUcEh0KdmsxnMXO@k8yFfauZAQq4Sv3lWDJTCrHN27goP96"

  var decfn = function(str){
        var shift=str.length
        var plain=""
        for (i=0; i<str.length; i++){
                if (key.indexOf(str.charAt(i))==-1){
                        ltr=str.charAt(i)
                        plain+=(ltr)
                } else {
                        ltr = (key.indexOf(str.charAt(i))-shift+key.length) % key.length
                        plain+=(key.charAt(ltr))
                }
        }
        return plain;
  }
  document.write("<a href='mailto:"+decfn(coded)+"'>"+decfn(codedlt)+"</a>")

Take that and put it in a js file, like getSignature.js, on a web server
somewhere.  Link to it with the C<E<lt>script...E<gt>E<lt>/scriptE<gt>> tags as
above and you're good to go.



=head1 AUTHOR

This is inspired by Tim Williams,
http://www.u.arizona.edu/~trw/spam/spam4.htm
Who says: As for the code it is freeware, use it as you like. If you like it 
please let me know. If you hate it let me know.

This script was written, and the javascript expanded on and the include feature
added 11/2004 by Kevin M. Goess.

=head1 COPYRIGHT AND LICENSE

Copyright 2004, 2022 by Kevin M. Goess

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CHANGES

=over 4

=item

2022-12-17 clean up, modernize, add option for mailto or just the text

=item

2005-10-29 encoding link text as well, some cleanup

=item 

2004-11-20 Initial version.

=back

=cut

use strict;
use Getopt::Long;
use HTML::Entities qw/encode_entities/;
use Pod::Usage;

Getopt::Long::Configure('no_ignore_case');

my $VERSION='0.03';

my ($verbose, $version, $help, $man, $email, $do_mailto, $linktext);

GetOptions (
     'email=s'         => \$email,
     'do-mailto'       => \$do_mailto,
     'linktext=s'        => \$linktext,
     'v|verbose'       => \$verbose,
     'V|version'       => \$version,
     'h|help'          => \$help,
     'm|man'           => \$man,
);
$version and print "$0 version $VERSION\n" and exit;
$man and pod2usage(-verbose => 2);
$help and pod2usage;

$email     || pod2usage("\nerror: email is required\n");
$linktext ||= $email;

$linktext = encode_entities($linktext);

my $key = "aZbYcXdWeVfUgThSiRjQkPlOmNnMoLpKqJrIsHtGuFvEwDxCyBzA1234567890@<>";
$key = scramble_key($key);

my $coded_email = encode($email, $key);
my $coded_linktext = encode($linktext, $key);

# a little assert to check my coding
my $reversed = decode($coded_email, $key);
die "something failed" unless $reversed eq $email;


my $docwrite;
if ($do_mailto) {
    $docwrite = q{"<a href='mailto:"+decfn(coded)+"'>"+decfn(codedlt)+"</a>"};
} else {
    $docwrite = q{decfn(coded)};
}

print <<EOL;
/* produced by email-obfuscator.pl */

(function() {

    coded = "$coded_email";
    codedlt = "$coded_linktext";
    key = "$key";

    var decfn = function(str){ 
        var shift=str.length
        var plain=""
        for (i=0; i<str.length; i++){
            if (key.indexOf(str.charAt(i))==-1){
                ltr=str.charAt(i)
                plain+=(ltr)
            } else {
                ltr = (key.indexOf(str.charAt(i))-shift+key.length) % key.length
                plain+=(key.charAt(ltr))
            }
        }
        return plain;
    }
    document.write($docwrite);
})();
EOL

sub scramble_key {
    my ($key) = shift;
    my @key = split('',$key);
    my $skey = '';
    while (@key){
        $skey .= splice(@key,rand(@key),1);
    }
    return $skey;
}
        
sub encode {
     my ($coded, $key) = @_;
     my $strlen=length($coded);
     my $link="";
     my $ltr;
     for (my  $i=0; $i<length($coded); $i++){
         my $char = substr($coded, $i, 1);
         if (index($key, $char)==-1){
             $ltr=$char;
             $link .=$ltr;
         } else {
             $ltr = (index($key,$char) + $strlen+length($key)+$ARGV[0]) % length($key);

             $link .= substr($key, $ltr, 1);
         }
     }
     return $link;
}
sub decode {
     my ($coded, $key) = @_;
     my $shift=length($coded);
     my $link="";
     my $ltr;
     for (my  $i=0; $i<length($coded); $i++){
         my $char = substr($coded, $i, 1);
         if (index($key, $char)==-1){
             $ltr=$char;
             $link .=$ltr;
         } else {
              #                  58          - 37          63
             $ltr = (index($key, $char)-$shift+length($key)) % length($key);
             $link .= substr($key, $ltr, 1);
         }
     }
     return $link;
}

