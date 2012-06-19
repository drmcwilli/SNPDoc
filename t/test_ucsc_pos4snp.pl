#!/usr/bin/perl -w

# test_ucsc_pos4snp
#
# Query the variation table for presence of a snp.
#

# Original connection info taken from snpdoc/lib/UCSC.pm on 04-Mar-2011
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 20-Oct-2011

use strict ;
use warnings ;
use DBI ;

# At this time (09-May-2011) valid values are 18 and 19
my $db_version = 19 ;
my $table_name = "" ;

if ($db_version == 19) {
  $table_name = "snp132" ;
} else {
  $table_name = "snp130" ;
}

my $position = shift ;

unless ($position) {
  die "Usage: $0 <pos>\n" ;
}
unless ($position =~ m/^chr([\dXY]+):(\d+)/) {
  die "Invalid position designation: $position, try again.\n" ;
}
my $chr = $1 ;
my $end = $2 ;                  # The NCBI position
my $start = $end - 1 ;          # The UCSC start position

$chr = "chr" . $chr ;

my $dbh = DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")
  or die("UCSC database unavailable.") ;

my $sql = "select name from $table_name where chrom='$chr' and chromStart=$start and chromEnd=$end" ;
print $sql, "\n" ;

my $sth = $dbh->prepare($sql)
    or die "Failed sql prep.\n" ;

$sth->execute() or
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


