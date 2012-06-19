#!/usr/bin/perl -w

# test_ucsc_pos
#
# Test to make sure the connection to the UCSC table browser data base
# works and to examine the returned query.
#
# Ascertain whether the position is in a gene.
#
# Original connection info taken from snpdoc/lib/UCSC.pm on 04-Mar-2011
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 09-May-2011

use strict ;
use warnings ;
use DBI ;

# At this time (09-May-2011) valid values are 18 and 19
my $db_version = 19 ;
my $table_name = "refGene" ;

my $position = shift ;

unless ($position) {
  die "Usage: $0 <pos>\n" ;
}
unless ($position =~ m/^chr([\dXY]+):(\d+)/) {
  die "Invalid position designation: $position, try again.\n" ;
}
my $chr = $1 ;
my $pos = $2 ;
$chr = "chr" . $chr ;

my $dbh = DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")
  or die("UCSC database unavailable.") ;

my $sth = $dbh->prepare('SELECT DISTINCT(name2) FROM refGene WHERE (chrom = ? AND txStart <= ?  AND txEnd >= ?)')
    or die "Failed sql prep.\n" ;

$sth->execute($chr, $pos, $pos) or
  die "UCSC database failed:\n " . $sth->errstr ;

print "\n" ;
print "DB version:", "\t", $db_version, "\n" ;
print "Table:", "\t",  $table_name, "\n" ;
print "Query position:", "\t", $position, "\n\n" ;


my $record = 0 ;
while (my @row = $sth->fetchrow_array) {
  print "|",  join("|", @row), "|", "\n" ;
  $record++ ;
}

print "\n" ;
print "Found ", $record, " record" ;
($record > 1) ? print "s\." : print "\." ;
print "\n" ;


