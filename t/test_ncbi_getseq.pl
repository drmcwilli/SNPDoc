#!/usr/bin/perl
#
# test_ncbi_getseq
#
# Test the query of NCBI and produce the output.  Code adapted from
# SNPDoc NCBIAccess::get_sequence_data.
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 18-May-2011

use strict ;
use warnings ;
use LWP::Simple ;
use feature qw(say) ;

my $msg ;

my $marker = shift ;
die "usage: test_ncbi_getseq marker\n"
  unless $marker ;

my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils"  ;
my $db      = "SNP"  ;
my $esearch = "$utils/esearch.fcgi?db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu.edu&term="  ;

my $report         = "Brief"  ;
my $esearch_result = ncbi_link_retrieve( $esearch . $marker )  ;

if ( !$esearch_result ) {
  die "[NCBIAccess::get_sequence_data] NCBI is down.\n"  ;
}

print "NCBI search result for marker: ", $marker, "\n\n" ;

print "esearch result:\n" ;
print "|", $esearch_result, "|\n\n" ;


$esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s  ;

my $Count    = $1  ;
my $QueryKey = $2  ;
my $WebEnv   = $3  ;
my $retstart = 0  ;
my $retmax   = 1  ;
my $efetch =
  "$utils/efetch.fcgi?"
  . "rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&"
  . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv"  ;

say "Results of pattern match:" ;
print "Count:\t",    "|", $Count,    "|\n" ;
print "QueryKey:\t", "|", $QueryKey, "|\n" ;
print "WebEnv:\t",   "|", $WebEnv,   "|\n" ;
print "\n" ;

my $efetch_result = ncbi_link_retrieve($efetch) ;
if ( !defined($efetch_result) ) {
  die("No result in efetch_result.") ;
}

# efetch result currently (02-Jul-2012) looks like (vertical bars added):
# |rs41518249	[Homo sapiens]	ACCTACTTCCCGCACTTCGACCTGAG	A/C	CACGGCTCTGCCCAGGTTAAGGGCC|

print "efetch result: |", $efetch_result, "|\n" ;

my @tmp = split( "\n", $efetch_result )  ;

print "After split on newlines: |", join("|", @tmp), "|\n" ;

my @data ;
foreach my $item (@tmp) {
  my @flds = split(/\t/, $item) ;
  if ((scalar @flds == 5) &&
      ($flds[0] eq $marker)) {
    @data = @flds ;
  }
}

if ((!@data) ||
    ($data[2] !~ /[ACTG]+/)) {
  $msg = "Brief summary failed to give sequence for marker $marker." ;
  print $msg, "\n" ;
} else {
  my $fiveprime  = $data[2]  ;

  my $a1 ;
  my $a2 ;
  if ($data[3] =~ m/([ACTG])\/([ACTG])/) {
    $a1 = $1 ;
    $a2 = $2 ;
  }

  my $threeprime = $data[4]  ;

  # Clean up length to 20.
  $fiveprime  = substr( $fiveprime,  -20, 20 )  ;
  $threeprime = substr( $threeprime, 0,   20 )  ;

  my $dna1 = $fiveprime . $a1 . $threeprime ;
  my $dna2 = $fiveprime . $a2 . $threeprime ;

  print "fiveprime: |", $fiveprime, "|\n" ;
  print "threeprime: |", $threeprime, "|\n" ;
  print "a1: |", $a1, "|\n" ;
  print "a2: |", $a2, "|\n" ;

}

####  Functions #####

sub ncbi_link_retrieve {
  my $efetch = shift  ;

  my $fetch_result ;
  my $wait_time = 180 ;      # This is the LWP::UserAgent default, but be explicit

  my $ua = LWP::UserAgent->new() ;
  $ua->timeout($wait_time) ;

  my $result = $ua->get($efetch) ;
  if ($result->code() =~ m/^5/) {
    print "[NCBIAccess::ncbi_link_retrieve] Server error accessing NCBI: ", $result->status_line(), "\n" ;
  }
  elsif ($result->code() =~ m/^4/) {
    my $client_error ;
    if ($result->content() =~m|<h2>Error occurred: (.+)</h2>|) {
      $client_error = $1 ;
    }
    print "[NCBIAccess::ncbi_link_retrieve] Problem accessing NCBI: ", $result->status_line(), "\n" ;
    print "\t", $client_error, "\n" ;
  }
  else {
    $fetch_result = $result->content() ;
  }

  return $fetch_result  ;
} # end ncbi_link_retrieve
