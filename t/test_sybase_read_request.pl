#!/usr/bin/perl

use strict ;
use warnings ;

# use lib 'usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/Sybase' ;
# use Sybase ;

use DBI ;

my $version = 19 ;

my $dbh = DBI->connect("DBI:Sybase:server=sqlprod.phs.wfubmc.edu","wakegenperl","wg34p9sz",
                       {syb_deadlock_retry => 3, syb_deadlock_sleep => 5 , PrintError => 1}) ;

my $sth = $dbh->prepare("SELECT * FROM vDistinctMarkerRequests WHERE build = 'hg$version' ")
  or die "Could not prep SQL statement" ;

while (my @row = $sth->fetchrow_array) {
  print join("|", @row), "\n" ;
}

print "After \"use DBI\"\n" ;

# foreach (@INC) {
#   print $_, "\n" ;
# }
