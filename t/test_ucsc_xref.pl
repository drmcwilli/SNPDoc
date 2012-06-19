#!/usr/bin/perl
#
# test_ucsc_xref
#
# Test query of kgXref
#
# Code adapted from UCSC.pm
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 09-May-2011

use strict ;
use warnings ;
use DBI ;

my $db_version = 19 ;
my $table = "kgXref" ;

my $dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")
  or die("Could not connect to UCSC kgXref.\n")  ;

my $sth = $dbh->prepare('SELECT kgID,description FROM kgXref WHERE geneSymbol = ?')
  or die "Could not prepare select statemnt.\n" ;

# BC032353 from the kgXref table description returns 3 rows (5/9/11)
# see more below
my $gene = shift ;
die "usage: $0 <gene_name>\n" unless $gene ;

$sth->execute($gene)
  or die "UCSC database query failed:\n " . $sth->errstr  ;

print "Database version:\t", $db_version, "\n" ;
print "Table:\t", $table, "\n" ;
print "Query:\t", $gene, "\n" ;
print "Results:\n" ;

my $cnt = 0 ;
while (my @row = $sth->fetchrow_array()) {
  print "$cnt:\t", "|", join("|", @row), "|\n" ;
  $cnt++ ;
}
print "End results.\n" ;


exit 0 ;

__END__

+------------+---------------------------------------------------------------------------+
| geneSymbol | description                                                               |
+------------+---------------------------------------------------------------------------+
| BC032353   | Homo sapiens cDNA FLJ36366 fis, clone THYMU2007824.                       |
| AX748260   | Homo sapiens cDNA FLJ36366 fis, clone THYMU2007824.                       |
| BC048429   | Homo sapiens cDNA clone IMAGE:5275617, **** WARNING: chimeric clone ****. |
| OR4F5      | olfactory receptor, family 4, subfamily F,                                |
| OR4F5      | olfactory receptor, family 4, subfamily F,                                |
| DQ575955   | Homo sapiens cDNA FLJ45445 fis, clone BRSSN2013696.                       |
| DQ574721   | Homo sapiens cDNA FLJ45445 fis, clone BRSSN2013696.                       |
| OR4F16     | olfactory receptor, family 4, subfamily F,                                |
| BC036251   | Homo sapiens cDNA clone IMAGE:5268125.                                    |
| AK026901   | Homo sapiens cDNA: FLJ23248 fis, clone COL03555.                          |
+------------+---------------------------------------------------------------------------+
