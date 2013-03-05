#!/usr/bin/perl -w

# test_ucsc_snp
#
# Test to make sure the connection to the UCSC table browser data base
# works and to examine the returned query.
#

# Original connection info taken from snpdoc/lib/UCSC.pm on 04-Mar-2011
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
#
# 11-Nov-2011  Modify to take a file as input.


# At this time (04-Mar-2011) valid values are 18 and 19

use strict ;
use warnings ;
use DBI ;

my $db_version = 19 ;
my $table_name ;

my $marker = shift ;

if ($db_version == 19) {
  $table_name = "snp135CodingDbSnp" ;
} else {
  $table_name = "snp130CodingDbSnp" ;
}

my $dbh ;
unless ($dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu",
                                 "genomep",
                                 "password")) {
  print "Could not connect to UCSC: " . $dbh->errstr, "\n" ;
}

my $sql = "select peptides from $table_name where name = \'$marker\'" ;

my $sth ;
unless ($sth = $dbh->prepare($sql)) {
  print "Could not prepare SQL statement: " . $dbh->errstr, "\n" ;
}

unless ($sth->execute) {
  print "Could not execute query: " . $sth->errstr, "\n" ;
}

my @result = () ;
my $status = 0 ;

while (my @row = $sth->fetchrow_array) {
  push @result, \@row ;
  $status++ if $row[0] =~ m/X/ ;
}

$dbh->disconnect ;

print "# DB version:", "\t", $db_version, "\n" ;
print "# Table:", "\t",  $table_name, "\n" ;
foreach my $row (@result) {
  print "Result: |", join("|", @$row), "|\n" ;
}
print "Status: ", $status, "\n" ;

exit 0 ;

__END__
