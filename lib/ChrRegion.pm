package ChrRegion;

use DBI;

use strict;
use warnings;

=head1 NAME

ChrRegion - Parse a region using UCSC database.

Expects a file to be passed with this form:

  outputfile.txt, optional extra column headers
  chr1:pos1-pos2, extra columns optional ...

=head1 Richard T. Guy

=head1 Description

A part of the SNPDoc program.

=head1 Methods

=head2 parse_region

=cut

sub parse_region {
  shift ;                       # shift off the class id
  my $infile = shift ;
  my $timestamp = shift ;
  my %snp_hash ;

  open(IN, $infile) or
    die("[ChrRegion::parse_region] Can not open file $infile for region reading: $!.") ;

  my @lines = <IN> ;
  my $header = shift @lines ;
  chomp $header ;
  # Check whether matches the pattern.  If so, fail.
  if ($header =~ m/chr[\dXY]+:\d+-\d+/) {
    die("[ChrRegion::parse_region] First line of region matched region pattern.  Please insert file first:\n$header") ;
  }
  my @head = split(/,/, $header) ;
  $header = shift @head ;

  open(OUT, "> $header") or
    die("[ChrRegion::parse_region] Can not open file for region writing.") ;
  print OUT "SNP,Input Region" ;
  while (@head) {
    print OUT ",", (shift @head) ;
  }
  print OUT "\n" ;

  # Get the DB set up.
  my $dbh = DBI->connect("DBI:mysql:database=hg18;host=genome-mysql.cse.ucsc.edu","genomep","password") or
    die "[ChrRegion::parse_region] Cannot get UCSC connection\n" ;
  my $sth = $dbh->prepare('SELECT name FROM snp130 where chrom = ? AND chromStart > ? AND chromEnd < ?') or
    die "[ChrRegion::parse_region] Cannot prepare statement\n" ;

  while (@lines) {
    my $line = shift @lines ;
    chomp $line ;
    my @single = split(/,/, $line) ;
    $line = shift @single ;
    if ($line =~ m/(chr[\dXY]+):(\d+)-(\d+)/) {
      my $chr   = $1 ;
      my $start = $2 . "" ;
      my $end   = $3 . "" ;

      if ($end-$start<=0) {
        print "Malformed line: $line\n" ;
        next ;
      }

      ### Make the database call then parse results.
      $sth->execute($chr, $start, $end)
        or die "[ChrRegion::parse_region] UCSC DB region search failed\n" ;

      while (my @data = $sth->fetchrow_array()) {
        my $snp = $data[0] ;
        print OUT $snp, ",$line" ;
        foreach my $s (@single) {
          print OUT ",",($s) ;
        }
        print OUT "\n" ;
      }
      print "Line $line started.\n" ;
    } else {
      warn ("Skipping line $line \n") ;
    }
  }  # end while lines

  $dbh->disconnect ;

  close(IN) ;
  close(OUT) ;
  return $header ;

} # end parse_region

=head2 fetch_region

Fetch the snps in a region from UCSC genome tables database.  Caller
validates the region suppolied.

ToDo: Should we die on connection errors or return and continue with
      the next query.

=cut

sub fetch_region {
  my $class  = shift ;
  my $data   = shift ;
  my $region = shift ;

  my $chr ;
  my $start ;
  my $end ;

  if ($region =~ m/(chr[\dXY]+):(\d+)-(\d+)/) {
    $chr   = $1 ;
    $start = $2 ;
    $end   = $3 ;
  }

  my $db_version = $data->version() ;
  my $table ;
  if ($db_version =~ m/19/) {
    $table = "snp131" ;
  } elsif ($db_version =~ m/18/) {
    $table = "snp130" ;
  } else {             # should only get here if there is a database update
    print "[ChrRegion::fetch_region] Did not recognize database version: $db_version, skipping region $region.\n" ;
    return 0 ;
  }

  $db_version = "hg" . $db_version ;

  my $dbh = DBI->connect("DBI:mysql:database=$db_version;host=genome-mysql.cse.ucsc.edu",
                         "genomep","password") or
    die "[ChrRegion::parse_region] Cannot get UCSC connection\n" ;

  my $sth = $dbh->prepare("SELECT name FROM $table where chrom = ? AND chromStart > ? AND chromEnd < ?") or
    die "[ChrRegion::parse_region] Cannot prepare statement\n" ;

  $sth->execute($chr, $start, $end)
    or die "[ChrRegion::parse_region] UCSC DB region search failed\n" ;

  my @snps = () ;
  while (my @row = $sth->fetchrow_array()) {
    print join("|", @row), "\n" ;
    push @snps, $row[0] ;
  }

  return \@snps ;

} # end fetch_region

1 ;
