#!/usr/bin/perl
#
# test_ncbi_getsnp
#
# Test the query of NCBI and produce the output.  Code adapted from
# SNPDoc NCBIAccess::get_snpinfo.
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 18-May-2011

use strict ;
use warnings ;
use LWP::Simple ;
use feature qw(say) ;

# Load from NCBI.
# variables used in API for NCBI.
my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils" ;
my $db      = "SNP" ;
my $report  = "DocSet" ;
my $esearch = "$utils/esearch.fcgi?"
  . "db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfumbc.edu&term=" ;

my $marker = shift ;
die "usage: test_ncbi_getsnp <marker>\n"
  unless $marker ;

say "Search using accessor: $0" ;
say "Conducted ", scalar localtime() ;
say "NCBI search result for marker: $marker" ;
print "\n" ;

my $esearch_result = ncbi_link_retrieve( $esearch . $marker ) ;

$esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s ;

say "ESearch result:" ;
print "|", $esearch_result, "|\n" ;
print "\n" ;

my $Count    = $1 ;
my $QueryKey = $2 ;
my $WebEnv   = $3 ;
my $retstart = 0 ;
my $retmax   = 1 ;

say "Results of pattern match:" ;
say "Count:\t|$Count|" ;
say "QueryKey:\t|$QueryKey|" ;
say "WebEnv:\t|$WebEnv|" ;
print "\n" ;

my $efetch = "$utils/efetch.fcgi?" .
  "rettype=$report&retmode=text&retstart=$retstart&" .
  "retmax=$retmax&db=$db&query_key=$QueryKey&tool=snpdoc&" .
  "email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv" ;

my $efetch_result = ncbi_link_retrieve($efetch) ;
if ( !defined($efetch_result) ) {
  die("[NCBIAccess::get_snpinfo] Error 1: NCBI failed to return (and failcatch did not work.)\n") ;
}

say "EFetch result:" ;
print "|", $efetch_result, "|\n" ;
print "\n" ;

say "EFetch parsing results:" ;

my $chr = "" ;
my $pos = "" ;

my $chr_flag = 0 ;
if ( $efetch_result =~ m/CHROMOSOME BASE POSITION=([\dXY]+):(\d+)/ ) {
  $chr_flag++ ;
  $chr = $1 ;
  $pos = $2 ;
} elsif ( $efetch_result =~ m/CHR=Multi/ ) {
  $pos = "Multiple entries" ;
  $chr = "Multiple entries" ;
}
say "Chr:\t|$chr|" ;
say "Pos:\t|$pos|" ;

# Find gene, geneid, genefunction.  Here we want to store that information and implant it at the end of the method.
my $gene         = "" ;
my $geneid       = "" ;
my $genefunction = "" ;
if ( $efetch_result =~ m/GENE/ ) {
  $efetch_result =~ m/GENE=(\S+)\nLOCUS_ID=(\S+)\nFXN_CLASS=(\S+)/ ;
  $gene         = $1 ;
  $geneid       = $2 ;
  $genefunction = $3 ;
}
say "Gene:\t|$gene|" ;
say "GeneId:\t|$geneid|" ;
say "GeneFunction:\t|$genefunction|" ;
print "\n" ;

#
# Finish by building the link.
#
$efetch_result =~ m/TAX_ID=(\d+)/ ;
my $taxid = $1 ;
say "TaxID:\t|$taxid|" ;

my $chr_url = "" ;
if ($chr_flag) {
  $chr_url = "http://www.ncbi.nlm.nih.gov/mapview/map_search.cgi?taxid="
            . $taxid
            . "&query="
            . $marker ;
}
say "URL Construct:\t|$chr_url|" ;
print "\n" ;

$report         = "Brief" ;
$esearch_result = ncbi_link_retrieve($esearch . $marker) ;

if ( !$esearch_result ) {
  die "[NCBIAccess::get_snpinfo] NCBI is down.\n" ;
}

say "ESearch Result:" ;
say "|", $esearch_result, "|\n" ;
print "\n" ;

$esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s ;

$Count    = $1 ;
$QueryKey = $2 ;
$WebEnv   = $3 ;
$retstart = 0 ;
$retmax   = 1 ;

say "Results of pattern match:" ;
say "Count:\t|$Count|" ;
say "QueryKey\t|$QueryKey|" ;
say "WebEnv:\t|$WebEnv|" ;
print "\n" ;

$efetch =
  "$utils/efetch.fcgi?"
  . "rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&"
  . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv" ;

# Pretty sure we might just get rid of this?
$efetch_result = ncbi_link_retrieve($efetch) ;
if ( !defined($efetch_result) ) {
  die("[NCBIAccess::get_snpinfo] Error 1: NCBI failed to return (and failcatch did not work.)\n") ;
}

say "EFetch Result:" ;
say "|", $efetch_result, "|\n" ;
print "\n" ;

# Scrape the line for our dna sequence.

my @temp0 = split( "\n", $efetch_result ) ;
shift @temp0 ;
shift @temp0 ;

$a = shift @temp0 ;

my $dna1 = "" ;
my $dna2 = "" ;
my $allele1 = "" ;
my $allele2 = "" ;

my @dnasplit = split( /\[|\]|\//, $a ) ;
say "Result of dnasplit:" ;
print "|", join("|", @dnasplit), "|\n" ;
print "\n" ;

if ( scalar @dnasplit < 4 ) {
  print "[NCBIAccess::get_snpinfo] ERROR: Brief summary failed to give sequence\n" ;
} else {
  my $fiveprime  = shift @dnasplit ;
  my $a1         = shift @dnasplit ;
  my $a2         = shift @dnasplit ;
  my $threeprime = shift @dnasplit ;

  # Clean up length to 20.
  $fiveprime  = substr( $fiveprime,  -20, 20 ) ;
  $threeprime = substr( $threeprime, 0,   20 ) ;

  $dna1 = $fiveprime . $a1 . $threeprime ;
  $dna2 = $fiveprime . $a2 . $threeprime ;
  $allele1 = $a1 ;
  $allele2 = $a2 ;
}

say "Result of sequence operations:" ;
say "DNA1:\t|$dna1|" ;
say "DNA2:\t|$dna2|" ;
say "Allele1:\t|$allele1|" ;
say "Allele2:\t|$allele2|" ;


sub ncbi_link_retrieve {
  my $efetch = shift  ;

  my $fetch_result = "NA" ;   # Return something, let the caller check
  my $wait_time = 180 ; # This is the LWP::UserAgent default, but be explicit

  my $ua = LWP::UserAgent->new() ;
  $ua->timeout($wait_time) ;

  my $result = $ua->get($efetch) ;
  if ($result->code() =~ m/^5/) {
    print "[NCBIAccess::ncbi_link_retrieve] Server error accessing NCBI: ", $result->status_line(), "\n" ;
  } elsif ($result->code() =~ m/^4/) {
    my $client_error ;
    if ($result->content() =~m|<h2>Error occurred: (.+)</h2>|) {
      $client_error = $1 ;
    }
    print "[NCBIAccess::ncbi_link_retrieve] Problem accessing NCBI: ", $result->status_line(), "\n" ;
    print "\t", $client_error, "\n" ;
  } else {
    $fetch_result = $result->content() ;
  }

  return $fetch_result  ;
}                               # end ncbi_link_retrieve
