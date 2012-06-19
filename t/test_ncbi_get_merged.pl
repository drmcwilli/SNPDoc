#!/usr/bin/perl
#
# test_ncbi_get_merged
#
# Test the query of NCBI for merged snps and return the output for
# examination.  Code adapted from # SNPDoc NCBIAccess::get_merged.
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 21-Nov-2011
#

use strict ;
use warnings ;
use LWP::Simple ;
use feature qw(say) ;

my $msg ;

my $marker = shift ;
die "usage: test_ncbi_get_merged marker\n"
  unless $marker ;


my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils"  ;
my $db      = "SNP"  ;
my $report  = "XML"  ;
my $esearch = "$utils/esearch.fcgi?"
  . "db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu&term="  ;

my $esearch_result = ncbi_link_retrieve( $esearch . $marker )  ;
if ( !defined($esearch_result) ) {
  $msg = "Could not execute NCBI esearch for $marker." ;
  say $msg ;
}

print "NCBI esearch result for marker: ", $marker, "\n\n" ;

print "|", $esearch_result, "|\n\n" ;

# check for missing
if ( $esearch_result =~ m/PhraseNotFound/ ) {
  $msg = "SNP not found in NCBI database."  ;
  say $msg ;
}

$esearch_result =~
  m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s  ;

my $Count    = $1  ;
my $QueryKey = $2  ;
my $WebEnv   = $3  ;
my $retstart = 0  ;
my $retmax   = 1  ;
my $efetch =
  "$utils/efetch.fcgi?"
  . "rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&"
  . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv"  ;

my $efetch_result = ncbi_link_retrieve($efetch)  ;

if ( !defined($efetch_result) ) {
  $msg = "Could not execute NCBI efetch for $marker." ;
  say $msg ;
}

say "efetch result:\n" ;
print "|", $efetch_result, "|\n" ;


if ( $efetch_result =~ m/<MergeHistory/ ) {
  my @merge_histories =
    grep ( /<MergeHistory/, split( /\n/, $efetch_result ) )  ;
  my $merge_list = ""  ;
  my $merge_temp  ;
  while (@merge_histories) {
    $merge_temp = shift @merge_histories  ;
    if ( $merge_temp =~ m/rsId="(\d+)"/ ) {
      $merge_list = $merge_list . "rs" . $1 . " "  ;
    }
  }
  say "Result of parsing <MergeHistory>:" ;
  print "|", $merge_list, "|\n" ;
}

exit 0 ;

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

__END__

