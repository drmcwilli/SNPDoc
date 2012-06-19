#!/usr/bin/perl
#
# generate_random_snps
#
# Generate random snp numbers for challenging snpdoc
#
# David R. McWilliams <dmcwilli@wfubmc.edu>
# 12-Apr-2011
#

use strict ;
use warnings ;

my $max = 2500000 ;
my $cnt = 10 ;

print "snp\n" ;

for (my $i=0; $i<10; $i++) {
  my $number = int(rand($max)) + 1 ;
  print "rs" . $number, "\n" ;
}

exit 0 ;
