
use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use HTML::Entities qw/encode_entities/;
use Template;

use bacds::Model::Event;

my (@found);

foreach my $f (qw/
    schedule2008
    schedule2009
    schedule2010
    schedule2011
    schedule2012
    schedule2013
    schedule2014
    schedule2015
    schedule2016
    schedule2017
    schedule2018
    schedule2019
    schedule2020
/) {
    push @found, bacds::Model::Event->load_all_from_really_old_schema(table => $f);
}
    
foreach my $f (qw/
    schedule2021
    schedule
/) {
    push @found, bacds::Model::Event->load_all_from_old_schema(table => $f);
}

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
        <th>startday</th>
        <th>type</th>
        <th>loc</th>
        <th>leader</th>
        <th>band</th>
    </tr>
[% FOREACH event IN events %]
    <tr>
      <td>[% event.startday %]</td>  
      <td>[% event.type %]</td>  
      <td>[% event.loc %]</td>  
      <td>[% event.leader %]</td>  
      <td>[% event.band %]</td>  
    </tr>
[% END %]
</table></body></html>
EOL

my $tt = Template->new;
my $the_code = `cat $0`;
encode_entities($the_code);
$tt->process(\$template, { events => \@found, the_code => $the_code });
