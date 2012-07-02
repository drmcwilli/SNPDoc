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

my $db_version = 18 ;
my $table_name ;

my $fh = shift ;

unless (open IN, "<", $fh) {
  die "Could not open $fh for input: $!" ;
}

if ($db_version == 19) {
  $table_name = "snp132" ;
} else {
  $table_name = "snp130" ;
}

my $dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")
  or die("UCSC database unavailable.") ;

my $sth = $dbh->prepare("SELECT chrom,chromStart,chromEnd,func,class FROM $table_name WHERE name = ?")
    or die "Failed sql prep.\n" ;

print "# DB version:", "\t", $db_version, "\n" ;
print "# Table:", "\t",  $table_name, "\n" ;
print join("\t", qw(name chrom chromStart chromEnd func class)), "\n" ;

LINE:
while (my $line = <IN>) {
  next LINE if $. == 1 ;
  chomp $line ;
  $line =~ s/\#.*$// ;
  next LINE if $line =~ m/^\s*$/ ;
  my $msg ;

  my ($snp, @rest) = split(/\s+/, $line) ;
  unless ($snp =~ m/^rs\d+$/) {
    $msg = "bad snp name" ;
    print join("\t", $snp, "NA", "NA", "NA" "NA", $msg), "\n" ;
    next LINE ;
  }

  unless ($sth->execute($snp)) {
    $msg = "Error accessing UCSC db: " . $sth->errstr ;
    print join("\t", $snp, "NA" x 4, $msg), "\n" ; 
    next LINE ;
  }

  while (my @row = $sth->fetchrow_array) {
    print join("\t", $snp, @row), "\n" ;
  }
}

exit 0 ;

__END__
