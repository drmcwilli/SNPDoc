#!/usr/bin/perl

use strict ;
use warnings ;

# use lib 'usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/Sybase' ;
# use Sybase ;

use DBI ;

my $version = 19 ;
my $build = "hg" . $version ;

my $dbh =  DBI->connect("DBI:Sybase:server=10.32.5.16",
                        "wakegenperl",
                        "wg34p9sz",
                        {
                         PrintError=>1}) ;

die "Unable to connect: $DBI::errstr\n" unless $dbh ;

# print "After connect.\n" ;

# my $sth = $dbh->prepare("SELECT * FROM _sysSnpDoc WHERE build = $build") ;
# my $sth = $dbh->prepare("SELECT * FROM _sysSnpDoc") ;
my $sth = $dbh->prepare("SELECT count(*) FROM _sysSnpDoc") ;

die "Cannot prepare query: $!"
  unless defined $sth ;

# print "After prepare.\n" ;

die "$DBI::errstr, $dbh->errstr\n"
  unless ($sth->execute()) ;

# print "After execute.\n" ;

while (my @row = $sth->fetchrow_array) {
  print join("\t", @row), "\n" ;
}

# print "After fetchrow_array.\n" ;

