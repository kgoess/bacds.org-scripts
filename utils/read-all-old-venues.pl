
use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use HTML::Entities qw/encode_entities/;
use Template;

use bacds::Model::Venue;

my @found = bacds::Model::Venue->load_all_from_old_schema(table => 'venue-old');


my $template = <<EOL;
<html>
<head>
<style>
table {
  width: 100%;
  table-layout: fixed;
}
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
}
tr:nth-child(even) {
  background-color: #D6EEEE;
}
</style>
</head>
<body>
This is the output from:
<pre>
[% the_code %]
</pre>
<table>
    <tr>
        <th>vkey</th>
        <th>hall</th>
        <th>address</th>
        <th>city</th>
        <th>zip</th>
        <th>comment</th>
        <th>type</th>
    </tr>
[% FOREACH venue IN venues %]
    <tr>
      <td>[% venue.vkey %]</td>  
      <td>[% venue.hall %]</td>  
      <td>[% venue.address %]</td>  
      <td>[% venue.city %]</td>  
      <td>[% venue.zip %]</td>  
      <td>[% venue.comment %]</td>  
      <td>[% venue.type %]</td>  
    </tr>
[% END %]
</table></body></html>
EOL

my $tt = Template->new;
my $the_code = `cat $0`;
encode_entities($the_code);
$tt->process(\$template, { venues => \@found, the_code => $the_code });
