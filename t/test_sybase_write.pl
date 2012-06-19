#!/usr/bin/perl

use strict ;
use warnings ;

# use lib 'usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/Sybase' ;
# use Sybase ;

use DBI ;

my $dbh =  DBI->connect("DBI:Sybase:server=10.32.5.16",
                        "wakegenperl",
                        "wg34p9sz",
                        {
                         PrintError=>1}) ;

die "Unable to connect: $DBI::errstr\n" unless $dbh ;

my $marker      = "rs99999999" ;
my $url         = "http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?rs=rs99999999" ;
my $ucscurl     = "http://www.genome.ucsc.edu/cgi-bin/hgTracks?&clade=mammal&org=Human&db=hg19&position=rs99999999" ;
my $snp_chr     = 1 ;
my $chrlink     = "http://www.chromo.db" ;
my $snp_pos     = 12345678 ;
my $near_gene1  = "near YFG1" ;
my $gene_link1  = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=search&term=YFG1" ;
my $near_gene2  = "near YFG2" ;
my $gene_link2  = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=search&term=YFG2" ;
my $gene        = "MFG" ;
$gene =~ s/'// ;
my $description = "My Favorite Gene" ;
my $geneURL     = "http://not.a.real.one.gov" ;
my $alias       = "ABC" ;
my $maxrisk     = 0 ;
my $maxclass    = "N/A" ;
my $version     = 18 ;
my $cpg         = 98765 ;
my $cnv         = "CNV" ;
my $merged_to   = "rs8888888" ;

my $sql = qq{exec spInsertSNPDoc '$marker','$url','$ucscurl','$snp_chr','$chrlink','$snp_pos','$near_gene1','$gene_link1','$near_gene2','$gene_link2','$gene','$description','$geneURL','$alias','$maxrisk','$cpg','$cnv','$maxclass','$version','$merged_to'} ;

my $sth = $dbh->prepare($sql) ;
die "Cannot prepare query: $!"
  unless defined $sth ;

die "$DBI::errstr, $dbh->errstr\n"
  unless ($sth->execute()) ;

$sth->finish() ;
$dbh->disconnect() ;
