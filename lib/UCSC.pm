package UCSC ;
my $VERSION = '0.1.3' ;

=head1 UCSC

  Interface with all UCSC information.

  Part of the snpdoc.pl program.

=head1 Author

  Richard T. Guy

=cut

use strict ;
use DBI ;
use Log::Log4perl ;

=head1 Methods

=head2 new

  Constructor.

=cut

sub new {
  my $invocant = shift ;
  my $class = ref($invocant) || $invocant ;
  my $self = { } ;
  bless($self, $class) ;
  return $self ;
}

=head2 db_version

  Get/Set database version.

=cut

sub db_version {
  my $self = shift ;
  $self->{dbversion} = shift if @_ ;
  return $self->{dbversion} ;
}

=head2 load_neargene

  Load and store a statement that will identify genes that are near a given SNP.

=cut

sub load_neargene {
  my $log = Log::Log4perl->get_logger("load_near_gene") ;
  my $msg = "In load_neargene." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $db_version = $self->{dbversion} ;

  my $dbh ;
  unless ($dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")) {
   $msg = "Could not connect to UCSC database" . $dbh->errstr ;
   $log->fatal($msg) ;
   die("[UCSC::load_neargene] Error 1: ", $msg, "\n") ;
  }
  $self->{data} = $dbh ;

  my $sth ;
  unless ($sth = $dbh->prepare('SELECT txStart,txEnd,name2 FROM refGene WHERE (chrom = ? AND ((txStart <= ? AND txStart >= ? ) OR (txEnd >= ? AND txEnd <= ?)))')) {
    $msg = "Could not prepare sql: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die("[UCSC::load_neargene] ", $msg, "\n") ;
  }

  $self->{handleRefGene} = $sth ;

} # end load_neargene

=head2 load_for_position

Load and store a statement that will identify genes that contain a given SNP.

=cut

sub load_for_position {
  my $log = Log::Log4perl->get_logger("load_for_position") ;
  my $msg = "In load_for position." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $db_version = $self->{dbversion} ;

  my $dbh ;
  unless ($dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")) {
    $msg = "Could not connect to UCSC database: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die("[UCSC::load_for_position] Error 1: $msg") ;
  }
  $self->{data} = $dbh ;

  my $sth ;
  my $sql = 'SELECT DISTINCT(name2) FROM refGene WHERE (chrom = ? AND txStart <= ?  AND txEnd >= ?)' ;
  unless ($sth = $dbh->prepare($sql)) {
    $msg = "Could not prepare statement: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die "[UCSC::load_for_position] $msg.\n" ;
  }
  $self->{handlePosition} = $sth ;

  $msg = "Leaving load_for_position." ;
  $log->debug($msg) ;

} # end load_for_position


=head2 load_for_snp_info

Connect to the UCSC database and return a handle for querying snp
information in tables 'snp131' or 'snp130'.

05-Oct-2012 Update hg19 table to 135

=cut

sub load_for_snp_info {
  my $log = Log::Log4perl->get_logger("load_for_snp_info") ;
  my $msg = "" ;

  $msg = "In load_for_snp_info." ;
  $log->debug($msg) ;

  my $self = shift ;

  my $db_version = $self->{dbversion} ;
  $msg = "db_version = $db_version" ;
  $log->debug($msg) ;

  my $dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")
    or die("[UCSC::load_for_snp_info] Error 1: UCSC database unavailable.") ;

  $msg = "After dbh=DBI->connect_cached." ;
  $log->debug($msg) ;

  $self->{data} = $dbh ;

  my $table_name = "snp135" ;
  if ($db_version < 19) {
    $table_name = "snp130" ;
  }

  $msg = "Querying table_name $table_name." ;
  $log->debug($msg) ;

  my $sth = $dbh->prepare("SELECT chrom,chromStart,func,class FROM $table_name WHERE name = ?")
    or die "[UCSC::load_for_snp_info] Failed sql prep.\n" ;

  $self->{handleSnpInfo} = $sth ;

  $msg = "At end of load_for_snp_info." ;
  $log->debug($msg) ;

} # end load_for_snp_info

=head2 load_for_gene_description

Connect to UCSC database and create a statement handle for querying table 'kgXref'.

=cut

sub load_for_gene_description {
  my $log = Log::Log4perl->get_logger("load_for_gene_description") ;
  my $msg = "In load_for_gene_description." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $db_version = $self->{dbversion} ;

  my $dbh ;
  unless ($dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")) {
    $msg = "Could not connect to UCSC database: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die("[UCSC::load_for_gene_description] Error 1: $msg.\n") ;
  }

  $self->{data} = $dbh ;

  my $sth ;
  unless ($sth = $dbh->prepare('SELECT kgID,description FROM kgXref WHERE geneSymbol = ?')) {
    $msg = "Could not prepare sql: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die "[UCSC::load_for_gene_description] $msg.\n" ;
  }
  $self->{handleGeneDesc} = $sth ;

} # end load_for_gene_description

=head2 get_from_position

  Try to deduce whether we are IN a gene.

=cut

sub get_from_position {
  my $log = Log::Log4perl->get_logger("get_from_position") ;
  my $msg = "In get_from_position." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;
  my $pos  = $data->position ;
  my $chr  = $data->chromosome ;

  my $gene_pos ;
  my $gene_title ;
  my %genes ;

  # Set up DB and retrieve.
  $self->load_for_position ;

  # handles created by previous method
  my $dbh = $self->{data} ;
  my $sth = $self->{handlePosition} ;
  $chr = "chr" . $chr ;

  unless ($sth->execute($chr, $pos, $pos)) {
    $msg = "UCSC database query failed: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die "[UCSC::get_from_position] $msg.\n" ;
  }

  my $gene_string ;
  while (my @dataIN = $sth->fetchrow_array()) {
    if ($gene_string) {
      $gene_string = join(",", $gene_string, $dataIN[0]) ;
      $self->get_gene_info($data, $dataIN[0]) ;
    } else {                    # it's the first one
      $gene_string = $dataIN[0] ;
      $self->get_gene_info($data, $dataIN[0]) ;
    }
  }
  $data->gene($gene_string) ;

} # end get_from_position

=head2 get_snpinfo

  Get the SNP information.  Updates data->chr, data->pos, data->gene,
  data->func and calls methods to update data->description.

  Returns early if marker is not found.

=cut

sub get_snpinfo {
  my $log = Log::Log4perl->get_logger("get_snpinfo") ;
  my $msg = "" ;

  $msg = "In get_snpinfo." ;
  $log->debug($msg) ;

  my $hasChrPosFlag = 0 ;
  my $self = shift ;
  my $data = shift ;

  my $name = $data->marker ;
  my $this_note = $data->note ;

  $self->load_for_snp_info ;

  # These are created by the previous method call
  my $dbh = $self->{data} ;
  my $sth = $self->{handleSnpInfo} ;

  # returns chrom, chromStart, func, class
  unless ($sth->execute($name)) {
    $msg = "Could not execute snp query $name on UCSC db: " . $sth->errstr ;
    $log->fatal($msg) ;
    die "[UCSC::get_snpinfo] Error 1: $msg.\n" ;
  }

  my $chr ;
  my $pos ;
  my $func_str ;
  my $foundOne = 0 ;      # Goes to 1 if we have at least one data row.

 ROW:
  while (my @dataIN = $sth->fetchrow_array()) {
    if (!$hasChrPosFlag) {
      $chr = $dataIN[0] ;
      if ($chr =~ m/^\s*chr([\dXY]+)/) {
        $chr = $1 ;
      }
      $pos = $dataIN[1] + 1 ;  # UCSC positions are zero-based
      $func_str = $dataIN[2] ;
      $hasChrPosFlag = 1 ;
      $foundOne = 1 ;
    } else {
      my $tChr = $dataIN[0] ;
      if ($tChr =~ m/^\s*chr([\dXY]+)/) {
        $tChr = $1 ;
      }
      if ($tChr ne $chr) {
        # $chr = "Multiple entries" ;
        # $pos = "Multiple entries" ;
        # $hasChrPosFlag = 0 ;
        # print "Multiple: $tChr, $chr\n" ;
        $foundOne = 0 ;
        $this_note->{"UCSC, multiple chromosome entries"}++ ;

        $msg = "Multiple chromosome entries for $name." ;
        $log->info($msg) ;
        last ROW ;
      } else {
        $this_note->{"UCSC, multiple position entries"}++ ;

        $msg = "Multiple position entries for $name." ;
        $log->info($msg) ;
      }
    } # end if/else hasChrPos
  } # end while dataIN

  if ($foundOne) {
    $data->position($pos) ;
    $data->chromosome($chr) ;

    my @funx = split(/,/, $func_str) ;
    if ((scalar @funx) == 0) {
      push @funx, "unknown" ;
    }

    # The following hack makes up for the lack up a function code
    # corresponding to Ensembl's 'STOP_LOST'.  Infer it from the
    # alternate peptide.

    unless (grep {/nonsense/} @funx) {
      push @funx, "stop-lost" if has_stop($data) ;
    }

    $data->func(\@funx) ;

  } else {
    $this_note->{"Not found at UCSC"}++ ;
    $data->note($this_note) ;

    $msg = "Marker $name not found at UCSC." ;
    $log->info($msg) ;
    return ;
  }

  if ($log->is_debug) {
    $msg = "After setting chr and pos; chr=$chr, pos=$pos; flag=$hasChrPosFlag" ;
    $log->debug($msg) ;
  }

  if ($hasChrPosFlag) {

    # Returns a gene name if the snp coordinates are between the gene start and end
    $self->load_for_position ;
    $sth = $self->{handlePosition} ;
    $chr = "chr" . $chr ;

    $msg = "Calling sth->execute with chr=$chr and pos=$pos." ;
    $log->debug($msg) ;

    unless ($sth->execute($chr, $pos, $pos)) {
      $msg = "Could not query UCSC db for marker $name: " . $sth->errstr ;
      $log->fatal($msg) ;
      die "[UCSC::get_snpinfo] Error 1: $msg.\n " ;
    }
    $msg = "After sth->execute." ;
    $log->debug($msg) ;

    my $geneString = "" ;
    if (my @dataIN = $sth->fetchrow_array()) {
      $geneString = $dataIN[0] ;

      # Call alias and description routines; updates data->description
      $self->get_gene_info($data, $dataIN[0]) ;
      while (my @dataIN = $sth->fetchrow_array()) {
        $geneString = $geneString . "," . $dataIN[0] ;
        # Call alias and description routines.
        $self->get_gene_info($data, $dataIN[0]) ;
      }
    }
    $data->gene($geneString) ;
    $msg = "At end of if hasChrPosFlag, genestring = $geneString." ;
    $log->debug($msg) ;
  }

  $data->note($this_note) ;
  $msg = "At end of get_snpinfo." ;
  $log->debug($msg) ;

}  # end get_snpinfo

=head2 get_gene_info

  Retrieve gene description and information.

  I'm given a gene symbol ($gene) and I use sth1 (kgXref) to get the
  internal name, called a kgID.

  I also get a description.  I should take the shortest such description
  and return just that.

=cut

sub get_gene_info {
  my $log = Log::Log4perl->get_logger("get_gene_info") ;
  my $msg = "In get_gene_info." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;
  my $gene = shift ;

  # Handle quotation marks
  $gene =~ s/([35])\'/$1-prime/g ;
  $gene =~ s/[\'\"]/ /g ;

  my %aliases ;                 # [drm] hash never filled (source of 'todo' in module header?)
  my %descriptions ;

  # returns kgID, description
  $self->load_for_gene_description ;
  my $sth1 = $self->{handleGeneDesc} ;

  unless ($sth1->execute($gene)) {
    $msg = "UCSC database query failed: " . $sth1->errstr ;
    $log->fatal($msg) ;
    die "[UCSC::get_gene_info] $msg.\n" ;
  }

  while (my @dataIN = $sth1->fetchrow_array()) {
    my $gid = $dataIN[0] ;   # [drm] variable not used

    $descriptions{$dataIN[1]}++ ;
  }
  my $desc = $data->description ;
  my @t = keys %descriptions ;
  my @sorted_t = sort { length($a) <=> length($b) } @t ;

  $desc = $desc . ";$sorted_t[0]" if $sorted_t[0] ;


  my $ali = $data->alias ;
  @t = keys %aliases ;
  $ali = $ali . ";@t" ;

  # Handle quotation marks
  $desc =~ s/'/-prime /g ;

  $data->description($desc) ;

  $" = " " ;  # [drm] $" = $LIST_SEPARATOR

  $msg = "Leaving get_gene_info." ;
  $log->debug($msg) ;

} # end get_gene_info

=head2 get_nearest

Pull the nearest three and five prime.

=cut

sub get_nearest {
  my $log = Log::Log4perl->get_logger("get_nearest") ;
  my $msg = "In get_nearest." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;
  my $pos        = $data->position ;
  my $chr        = $data->chromosome ;

  my $dist_u      = 9999999 ;
  my $dist_d      = 9999999 ;
  my $gene_name_u = "None within 500 kb" ;
  my $gene_name_d = "None within 500 kb" ;
  my $gene_pos ;
  my $gene_title ;
  my $temp_dist ;

  # If unable to find then don't try.
  if (($chr =~ /Multi/ or !$chr or !$pos) or
      ($pos =~ /\D/)) {
    $data->near_gene_d("") ;
    $data->near_dist_d("") ;
    $data->near_gene_link_d("") ;
    $data->near_gene_u("") ;
    $data->near_dist_u("") ;
    $data->near_gene_link_u("") ;
    return ;
  }

  my $left = $pos - 500000 ;
  if ($left < 0) {
    $left = 0 ;
  }
  my $right    = $pos + 500000 ;

  # Set up DB and retrieve.
  $self->load_neargene ;
  my $dbh = $self->{data} ;
  my $sth = $self->{handleRefGene} ;

  $chr = "chr" . $chr ;
  unless ($sth->execute($chr, $right, $pos, $left, $pos)) {
    $msg = "Could not query UCSC database for nearest: " . $sth->errstr ;
    $log->warn($msg) ;
  }

  # Now we have them all.  Find closest.
  while (my @dataIN = $sth->fetchrow_array()) {
    $gene_title = $dataIN[2] ;
    $temp_dist = $dataIN[0] - $pos ;
    if ($temp_dist > 0) {      # looking upstream
      if ($temp_dist < 500000 and $temp_dist < $dist_u) {
        # new match.
        $dist_u = $temp_dist ;
        $gene_name_u = $gene_title ;
      }
    } else {                   # Looking downstream.
      $temp_dist = $pos-$dataIN[1] ;
      if ($temp_dist < 500000 and $temp_dist < $dist_d) {
        # new match.
        $dist_d = $temp_dist ;
        $gene_name_d = $gene_title ;
      }
    }
  }  # end while dataIN

  # Now we need to simply return the distances and the genes.
  if ($dist_u == 9999999) {
    $data->near_gene_u("") ;
    $data->near_dist_u(9999999) ;
    $data->near_gene_link_u("") ;
  } else {
    $dist_u /= 1000 ;
    $data->near_gene_u($gene_name_u) ;
    $data->near_dist_u($dist_u) ;
    $data->near_gene_link_u("http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=search&term=". $gene_name_u) ;
  }
  if ($dist_d == 9999999) {
    $data->near_gene_d("") ;
    $data->near_dist_d(9999999) ;
    $data->near_gene_link_d("") ;
  } else {
    $dist_d /= 1000 ;
    $data->near_gene_d($gene_name_d) ;
    $data->near_dist_d($dist_d) ;
    $data->near_gene_link_d("http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=search&term=". $gene_name_d) ;
  }

} # end get_nearest

=head2 get_conservation

  Retrieve the conservation score from the UCSC genome tables.

=cut

sub get_conservation {
  my $log = Log::Log4perl->get_logger("get_conservation") ;
  my $msg = "In get_conservation." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;

  my $db_version = $self->{dbversion} ;
  my $pos   = $data->position() ;
  my $chr   = $data->chromosome() ;
  my $score ;

  # As of 19-May-11
  my %cons_tables_hg = (
                        18 => "multiz17way",
                        19 => "multiz46way"
                        ) ;

  my $track_name = $cons_tables_hg{$db_version} ;
  my $table_name = $cons_tables_hg{$db_version} ;

  my $dbh ;
  unless ($dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;hgta_group=compGeno; hgta_track=$track_name&hgta_table=$table_name;host=genome-mysql.cse.ucsc.edu",
                                   "genomep","password")) {
    $msg = "Could not connect to UCSC database: " . $dbh->errstr ;
    $log->warn($msg) ;
    warn("[UCSC::get_conservation] $msg\n.") ;
  }

  my $sth ;
  unless ($sth = $dbh->prepare("SELECT score FROM $table_name WHERE chrom = ? and chromStart < ? and chromEnd > ?")) {
    $msg = "Could prepare sql: " . $dbh->errstr ;
    $log->warn($msg) ;
    warn "[UCSC::get_conservation] $msg.\n" ;
  }
  $chr = "chr" . $chr ;

  unless ($sth->execute($chr, $pos, $pos)) {
    $msg = "Query of $table_name failed: " . $sth->errstr ;
    $log->warn($msg) ;
    warn "[UCSC::get_conservation] $msg.\n" ;
  }

  my @row = $sth->fetchrow_array ;
  $score = $row[0] || 'NA' ;
  $data->cons_multiz($score) ;

  return 1 ;

} # end get_conservation

=head2 is_snp

 Check whether a position is a named snp.

 05-Oct-2012 Update hg19 table to 135.

=cut

sub is_snp {
  my $log = Log::Log4perl->get_logger("is_snp") ;
  my $msg = "In is_snp." ;
  $log->debug($msg) ;

  my $status = 0 ;
  my $self   = shift ;
  my $data   = shift ;

  $msg = "Contents of data structure:\n" . $data->_return_data() ;
  $log->debug($msg) ;

  my $db_version = $data->version() ;
  my $chr        = "chr" . $data->chromosome() ;
  my $end        = $data->position() ;
  my $start      = $end - 1 ;

  my $table_name = "" ;

  if ($db_version == 19) {
    $table_name = "snp135" ;
  } else {
    $table_name = "snp130" ;
  }

  my $dbh ;
  unless ($dbh = DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")) {
    $msg = "Could not connect to UCSC: " . $dbh->errstr ;
    $log->warn($msg) ;
  }

  my $sql = "select name from $table_name where chrom='$chr' and chromStart=$start and chromEnd=$end" ;

  my $sth ;
  unless ($sth = $dbh->prepare($sql)) {
    $msg = "Could not prepare statement handle: " . $dbh->errstr ;
    $log->warn($msg) ;
  }

  unless ($sth->execute()) {
    $msg = "Could not execute statement handle: " . $sth->errstr ;
    $log->warn($msg) ;
  }

  my $row = $sth->fetch ;
  $status = $row->[0] || 0 ;

  return $status ;

} # end is_snp

=head2 has_stop

 Check to see whether the variant produces a stop codon.  UCSC puts 'X'
 for the peptide produced from one of the stop codons.

 05-Oct-2012 Update hg19 table to 135.

=cut

sub has_stop {
  my $log = Log::Log4perl->get_logger("has_stop") ;
  my $msg = "In has_stop." ;
  $log->debug($msg) ;

  my $status = 0 ;
  my $data   = shift ;

  my $marker     = $data->marker ;
  my $db_version = $data->version ;

  my $table_name ;
  if ($db_version == 19) {
    $table_name = "snp135CodingDbSnp" ;
  } else {
    $table_name = "snp130CodingDbSnp" ;
  }

  my $dbh ;
  unless ($dbh=DBI->connect_cached("DBI:mysql:database=hg$db_version;host=genome-mysql.cse.ucsc.edu","genomep","password")) {
    $msg = "Could not connect to UCSC: " . $dbh->errstr ;
    $log->warn($msg) ;
  }

  my $sql = "select peptides from $table_name where name = \'$marker\'" ;
  $msg = "SQL statement: $sql" ;
  $log->debug($msg) ;

  my $sth ;
  unless ($sth = $dbh->prepare($sql)) {
    $msg = "Could not prepare SQL statement: " . $dbh->errstr ;
    $log->warn($msg) ;
  }

  unless ($sth->execute) {
    $msg = "Could not execute query: " . $sth->errstr ;
    $log->info($msg) ;
  }

  while (my @row = $sth->fetchrow_array) {
    $status++ if $row[0] =~ m/X/ ;
  }

  $dbh->disconnect ;

  return $status ;

} # end has_stop

return 1 ;
