#!/usr/bin/perl
#
# test_ucsc_cons
#
# Test retrieval of conservation info from UCSC table browser.
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
#
# 29-Apr-11
#

# From the command line the db can be queried thusly:
# mysql --user=genome --host=genome-mysql.cse.ucsc.edu -A
# select score, chromStart, chromEnd from hg18.multiz17way where chrom='chr1' and chromStart <1100 and chromEnd >1100 ;

# DB Fields from the UCSC table description:
# |bin|chrom|chromStart|chromEnd|ext|File|offset|score|

use strict ;
use warnings ;
use DBI ;

# as of 29-Apr-11
my %cons_tables_hg = (
                      18 => "multiz17way",
                      19 => "multiz46way"
                     ) ;

# Index of the score field for the 'multiz##tables'
my $score_field = 6 ;

my $db_version = 19 ;

my $track_name = $cons_tables_hg{$db_version} ;
my $table_name = $cons_tables_hg{$db_version} ;

# my $chr = 1 ;
# my $startpos = 204685497 ;
# my $endpos   = 204685498 ;
# my $offset   = 10 ;

# my $chr = 6 ;
# my $startpos = 30736061 ;
# my $endpos   = 30736061 ;
my $offset   = 10 ;

my $chr = 4 ;
my $startpos = 191040426 ;
my $endpos   = $startpos + 1 ;

my $dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;hgta_group=compGeno; hgta_track=$track_name&hgta_table=$table_name;host=genome-mysql.cse.ucsc.edu",
                            "genomep","password") or
  die("UCSC database unavailable.") ;


# my $sth = $dbh->prepare("SELECT score, chromStart, chromEnd FROM $table_name WHERE chrom = ? and chromStart < ? and chromEnd > ?")
#    or die "Failed sql prep.\n" ;

my $sth = $dbh->prepare("SELECT * FROM $table_name WHERE chrom = ? and chromStart < ? and chromEnd > ?")
  or die "Failed sql prep.\n" ;

$chr = "chr" . $chr ;

$sth->execute($chr, $startpos, $endpos) or
  die "Query of database table $table_name failed: " . $sth->errstr, "\n" ;

print "DB version:", "\t", $db_version, "\n" ;
print "Table:", "\t",  $table_name, "\n" ;
print "Chr:", "\t", $chr, "\n";
print "Start:", "\t", $startpos, "\n" ;
print "End:", "\t", $endpos, "\n" ;
print "\n" ;


while (my @row = $sth->fetchrow_array) {
  print "|", join("|", @row), "|", "\n" ;
  print "Score:\t|", $row[$score_field], "|\n" ;
}

