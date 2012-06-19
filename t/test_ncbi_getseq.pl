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

print "NCBI search result for marker:", $marker, "\n\n" ;

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

# Pretty sure we might just get rid of this?
my $efetch_result = ncbi_link_retrieve($efetch) ;
if ( !defined($efetch_result) ) {
  die("[NCBIAccess::get_sequence_data] Error 1: NCBI failed to return (and failcatch did not work.)\n")  ;
}

say "efetch result:\n" ;
print "|", $efetch_result, "|\n" ;


sub ncbi_link_retrieve {
  my $efetch = shift  ;

  my $fetch_result = "NA" ;  # Return something, let the caller check
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
