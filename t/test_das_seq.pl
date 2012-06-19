#!/usr/bin/perl
#
# test_das_seq
#
# Retrieve sequence from the UCSC DAS server.
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
#
# 27-Oct-2011  Intitiate
#

use strict ;
use warnings ;
use LWP ;

my $chr =  1 ;
my $pos = 11078893 ;
my $off = 10 ;

my $pos1 = $pos - $off ;
my $pos2 = $pos + $off ;

my $ua = LWP::UserAgent->new ;
$ua->timeout(10) ;

my $uri = "http://genome.ucsc.edu/cgi-bin/das/hg19/dna?segment=chr$chr:$pos1,$pos2" ;
my $response = $ua->get($uri) ;

if ($response->is_success) {
  print $response->decoded_content ;
}
else {
  die $response->status_line;
}


