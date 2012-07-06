#!/usr/bin/perl
#
# test_tfsearch
#
# Test query of cbrc TFSEARCH database
#
# David R. McWilliams <dmcwilli@wakehealth.edu>
#
# 02-Jul-2012 Initiate

use LWP::Simple ;

my $dna = "TATAAACAAAA" ;       # TATAA Box
my $dna = "TTCCCGCACTTCGACCTGAGACACGGCTCTGCCCAGGTTAA" ; # from snp in HBA2; should be no score

# my $tf_url = "http://www.cbrc.jp/htbin/nph-tfsearch?label=&seq=" ;   # pre 01-Jul-2012
my $tf_url = "http://mbs.cbrc.jp/htbin/nph-tfsearch?taxonomy=V&seq=" ;

my $tf_query = $tf_url . $dna ;

my $result = get($tf_query) ;

print "Results of query:\n" ;
print "=" x 78, "\n" ;
print $result, "\n" ;
print "=" x 78, "\n" ;

exit 0 ;
