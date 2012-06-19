package SNPData ;
my $VERSION = "0.1.3" ;

=head1 NAME

SNPData

=head1 Author

Richard T. Guy

=head1 DESCRIPTION

Data structure and accessors for the snp data.

=head1 Methods

=cut

=head2 new

Constructor

=cut

use Log::Log4perl ;
my $log = Log::Log4perl->get_logger("SNPData") ;

sub new {
  my $log = Log::Log4perl->get_logger("new") ;
  my $msg = "In constructor" ;
  $log->debug($msg) ;

  my $invocant = shift ;
  my $class = ref($invocant) || $invocant ;
  my $self = {  } ;
  bless($self, $class) ;
  return $self->clear ;
}

=head2 clear

=cut

sub clear {
  my $log = Log::Log4perl->get_logger("clear") ;
  my $msg = "In clear." ;
  $log->debug($msg) ;

  my $self = shift ;
  $self->{type}      = "" ;     # Type of variation (snp, cnv, indel, etc.)
  $self->{marker}    = "" ;     # SNP designation, set in snpdoc::main
  $self->{merged}    = "" ;     # Old name if merged (see merged_to below), set in ncbi::get_merged
  $self->{posit}     = "" ;     # Chromosome position, set by ucsc::get_snpinfo
  $self->{chrom}     = "" ;     # Chromosome number, set by ucsc::get_snpinfo

  $self->{risk}      = "" ;     # Risk score, filled by RiskMarker::calc_risk
  $self->{risk_ucsc} = "" ;     # Risk score calculated using the UCSC functional categories

  $self->{class}     = "" ;     # Risk classification, filled by RiskMarker::calc_risk
  $self->{class_ucsc} = "";     # Classification calculated using the UCSC functional categories

  $self->{ver}       = "" ;     # Database version, set in snpdoc::main
  $self->{web}       = "" ;     # URL to NCBI, set in snpdoc::process_snp
  $self->{ucweb}     = "" ;     # UCSC SNP URL, set in snpdoc::process_snp
  $self->{chr_web}   = "" ;     # URL to NCBI mapview, set in snpdoc::process_snp
  $self->{dna1}      = "" ;     # Allele 1 w/ 20 bases 5' and 20 bases 3', set in NCBIAccess::get_sequence_data
  $self->{dna2}      = "" ;     # Allele 2 w/ 20 bases 5' and 20 bases 3', set in NCBIAccess::get_sequence_data
  $self->{all1}      = "" ;     # Allele 1, set in NCBIAccess::get_sequence_data
  $self->{all2}      = "" ;     # Allele 2, set in NCBIAccess::get_sequence_data
  $self->{desc}      = "" ;     # Gene description, set by ucsc::get_gene_info
  $self->{alias}     = "" ;     # Gene alias, set by NCBIAccess::get_gene_alias
  $self->{nearu}     = "" ;     # Nearest upstream gene, set in ucsc::get_nearest
  $self->{distu}     = "" ;     # Distance to nearest upstream, set in ucsc::get_nearest
  $self->{neard}     = "" ;     # Nearest downstream gene, set in ucsc::get_nearest
  $self->{distd}     = "" ;     # Distance to nearest downstream, set in ucsc::get_nearest
  $self->{geneurl}   = "" ;     # ?, set by snpdoc::process_snp or :process_position
  $self->{nearlinku} = "" ;     # Link to upstream gene, set by ucsc::get_nearest
  $self->{nearlinkd} = "" ;     # Link to upstream gene, set by ucsc::get_nearest
  $self->{gene}      = "" ;     # Gene name, set by ucsc::get_snpinfo

  $self->{ensg}      = "" ;     # Deprecated; replace with ucsc 'func'
                                # 'Consequence' (synonymous/non), hold ensg numbers space delimited, set in
                                # EnsemblAccess::get_ensembl_data

  $self->{func}        = "" ;   # UCSC 'func'
  $self->{prot}        = "" ;   # Designates protein coding, set by EnsemblAccess::get_ensembl_data

  $self->{cpg}         = "" ;   # CpG position, set by snpdoc::get_cpg
  $self->{cnv}         = "" ;   # CNV position, set by snpdoc::get_cpg
  $self->{mergein}     = "" ;   # Merge history (see merged_here below), set in NCBIAccess::get_merged
  $self->{LD_hi}       = "" ;   # LD from Ensembl, set in snpdoc::process_snp
  $self->{cons_multiz} = "" ;   # UCSC conservation score, set in snpdoc::process_snp
  $self->{cons_phast}  = "" ;   # Not yet implemented
  $self->{note}        = {} ;   # Store messages from searches

  return $self ;
} # end clear

=head2 clone

=cut

sub clone {
  my $self = shift ;
  my $clne = new($self);                     # Calls the internal new.
                                             # my $clne = SNPData->new;  For the record, this also works.
  $clne->{type}        = $self->{type} ;
  $clne->{marker}      = $self->{marker} ;
  $clne->{merged}      = $self->{merged} ;
  $clne->{posit}       = $self->{posit} ;
  $clne->{chrom}       = $self->{chrom} ;

  $clne->{risk}        = $self->{risk} ;
  $clne->{risk_ucsc}   = $self->{risk_ucsc} ;

  $clne->{class}       = $self->{class} ;
  $clne->{class_ucsc}  = $self->{class_ucsc} ;

  $clne->{ver}         = $self->{ver} ;
  $clne->{web}         = $self->{web};       # URL
  $clne->{ucweb}       = $self->{ucweb} ;
  $clne->{chr_web}     = $self->{chr_web};   # Chromosome website.
  $clne->{dna1}        = $self->{dna1} ;
  $clne->{dna2}        = $self->{dna2} ;
  $clne->{all1}        = $self->{all1} ;
  $clne->{all2}        = $self->{all2} ;
  $clne->{desc}        = $self->{desc} ;
  $clne->{alias}       = $self->{alias} ;
  $clne->{nearu}       = $self->{nearu} ;
  $clne->{distu}       = $self->{distu} ;
  $clne->{neard}       = $self->{neard} ;
  $clne->{distd}       = $self->{distd} ;
  $clne->{geneurl}     = $self->{geneurl} ;
  $clne->{ensg}        = $self->{ensg} ;
  $clne->{func}        = $self->{func} ;
  $clne->{prot}        = $self->{prot} ;
  $clne->{cpg}         = $self->{cpg} ;
  $clne->{cnv}         = $self->{cnv} ;
  $clne->{mergein}     = $self->{mergein} ;
  $clne->{LD_hi}       = $self->{LD_hi} ;
  $clne->{cons}        = $self->{cons} ;
  $clne->{cons_multiz} = $self->{cons_multiz} ;
  $clne->{cons_phast}  = $self->{cons_phast} ;
  $clne->{note}        = $self->{note} ;
  return $clne ;
}

=head2 type

 getter/setter for the type of variant.

=cut

sub type {
  my $self = shift ;
  $self->{type} = shift if @_ ;
  return $self->{type} ;
}

=head2 marker

getter/setter for the snp.

=cut

sub marker {
  my $self = shift ;
  $self->{marker} = shift if @_ ;
  return $self->{marker} ;
}

=head2 merged_to

shift the original marker name to {merged}, update {marker} with the
new name.  set in NCBIAcess::get_merged.

=cut

sub merged_to {
  my $self = shift ;
  if (@_) {
    $self->{merged} = $self->{marker} ;
    $self->{marker} = shift ;
    return $self->{marker} ;
  } else {
    return -1 ;
  }                             # else there was an error.
}

=head2 marker_text

create marker text '(old) merged into (new)' if the user-supplied
marker was merged into a new name.  this is unpacked in dbwrite::put,
before writing to the database.

=cut

sub marker_text {
  my $self = shift ;
  if ($self->{merged}) {
    return $self->{merged} . " merged into " . $self->{marker} ;
  } else {
    return $self->{marker} ;
  }
}

=head2 merged_here

set in ncbiacess::get_merged.

=cut

sub merged_here {
  my $self = shift ;
  $self->{mergein} = shift if @_ ;
  return $self->{mergein} ;
}

=head2 position

=cut

sub position {
  my $self = shift ;
  $self->{posit} = shift if @_ ;
  return $self->{posit} ;
}

=head2 cpg

=cut

sub CpG {
  my $self = shift ;
  $self->{cpg} = shift if @_ ;
  return $self->{cpg} ;
}

=head2 cnv

=cut

sub CNV {
  my $self = shift ;
  $self->{cnv} = shift if @_ ;
  return $self->{cnv} ;
}

=head2 chromosome

=cut

sub chromosome {
  my $self = shift ;
  $self->{chrom} = shift if @_ ;
  return $self->{chrom} ;
}

=head2 risk

=cut

sub risk {
  my $self = shift ;
  $self->{risk} = shift if @_ ;
  return $self->{risk} ;
}

=head2 risk_ucsc

=cut

sub risk_ucsc {
  my $self = shift ;
  $self->{risk_ucsc} = shift if @_ ;
  return $self->{risk_ucsc} ;
}

=head2 classification

  Get/Set the FastSNP classification.

=cut

sub classification {
  my $self = shift ;
  $self->{class} = shift if @_ ;
  return $self->{class} ;
}

=head2 classification_ucsc

  Get/Set the FastSNP classification using the UCSC functional
  categories.

=cut

sub classification_ucsc {
  my $self = shift ;
  $self->{class_ucsc} = shift if @_ ;
  return $self->{class_ucsc} ;
}

=head2 version

set ucsc database version.

=cut

sub version {
  my $self = shift ;
  $self->{ver} = shift if @_ ;
  return $self->{ver} ;
}

=head2 URL

=cut

sub URL {
  my $self = shift ;
  $self->{web} = shift if @_ ;
  return $self->{web} ;
}

=head2 UCSC_URL

=cut

sub UCSC_URL {
  my $self = shift ;
  $self->{ucweb} = shift if @_ ;
  return $self->{ucweb} ;
}

=head2 Chr_URL

=cut

sub Chr_URL {
  my $self = shift ;
  $self->{chr_web} = shift if @_ ;
  return $self->{chr_web} ;
}

=head2 dna1

allele 1 w/ 20 bases 5' and 20 bases 3'

=cut

sub dna1 {
  my $self = shift ;
  $self->{dna1} = shift if @_ ;
  return $self->{dna1} ;
}

=head2 dna2

allele 2 w/ 20 bases 5' and 20 bases 3'

=cut

sub dna2 {
  my $self = shift ;
  $self->{dna2} = shift if @_ ;
  return $self->{dna2} ;
}

=head2 allele1

=cut

sub allele1 {
  my $self = shift ;
  $self->{all1} = shift if @_ ;
  return $self->{all1} ;
}

=head2 allele2

=cut

sub allele2 {
  my $self = shift ;
  $self->{all2} = shift if @_ ;
  return $self->{all2} ;
}

=head2 gene

=cut

sub gene {
  my $self = shift ;
  $self->{gene} = shift if @_ ;
  return $self->{gene} ;
}

=head2 gene_id

 called from ncbiacess.pm.  apparently not used.

=cut

sub gene_id {
  my $self = shift ;
  $self->{geneid} = shift if @_ ;
  return $self->{geneid} ;
}

=head2 gene_fxn

=cut

sub gene_fxn {
  my $self = shift ;
  $self->{genefxn} = shift if @_ ;
  return $self->{genefxn} ;
}

=head2 gene_url

=cut

sub gene_URL {
  my $self = shift ;
  $self->{geneurl} = shift if @_ ;
  return $self->{geneurl} ;
}

=head2 description

=cut

sub description {
  my $self = shift ;
  $self->{desc} = shift if @_ ;
  return $self->{desc} ;
}

=head2 alias

=cut

sub alias {
  my $self = shift ;
  $self->{alias} = shift if @_ ;
  return $self->{alias} ;
}

=head2 near_gene_u

=cut

sub near_gene_u {
  my $self = shift ;
  $self->{nearu} = shift if @_ ;
  return $self->{nearu} ;
}

=head2 near_gene_d

=cut

sub near_gene_d {
  my $self = shift ;
  $self->{neard} = shift if @_ ;
  return $self->{neard} ;
}

=head2 near_dist_u

=cut

sub near_dist_u {
  my $self = shift ;
  $self->{distu} = shift if @_ ;
  return $self->{distu} ;
}

=head2 near_dist_d

=cut

sub near_dist_d {
  my $self = shift ;
  $self->{distd} = shift if @_ ;
  return $self->{distd} ;
}

=head2 near_gene_text_u

=cut

sub near_gene_text_u {
  $self = shift ;
  if ($self->gene) {
    return "" ;
  } elsif ($self->near_dist_u !~ m/9999/) {
    if ($self->near_dist_u) {
      return $self->near_dist_u . " kb from " . $self->near_gene_u ;
    }
  } else {
    return "None within 500 kb." ;
  }
}

=head2 near_gene_text_d

=cut

sub near_gene_text_d {
  $self = shift ;
  if ($self->gene) {
    return "" ;
  } elsif ($self->near_dist_d !~ m/9999999/) {
    if ($self->near_dist_d) {
      return $self->near_dist_d . " kb from " . $self->near_gene_d ;
    }
  } else {
    return "None within 500 kb" ;
  }
}

=head2 near_gene_link_u

=cut

sub near_gene_link_u {
  $self = shift ;
  $self->{nearlinku} = shift if @_ ;
  return $self->{nearlinku} ;
}

=head2 near_gene_link_d

=cut

sub near_gene_link_d {
  $self = shift ;
  $self->{nearlinkd} = shift if @_ ;
  return $self->{nearlinkd} ;
}

=head2 consequence

=cut

sub consequence {
  $self = shift ;
  $self->{ensg} = shift if @_ ;
  return $self->{ensg} ;
}

=head2 protein_coding

=cut

sub protein_coding {
  $self = shift ;
  $self->{prot} = shift if @_ ;
  return $self->{prot} ;
}

=head2 LD_high

=cut

sub LD_high {
  my $self = shift ;
  $self->{LD_hi} = shift if @_ ;
  return $self->{LD_hi} ;
}

=head cons_multiz

  Get or set the UCSC multiz17 or multiz44 conservation score.

=cut

sub cons_multiz {
  my $self = shift ;
  $self->{cons_multiz} = shift if @_ ;
  return $self->{cons_multiz} ;
}

=head cons_phast

  Get or set the UCSC phast conservation score.

=cut

sub cons_phast {
  my $self = shift ;
  $self->{cons_phast} = shift if @_ ;
  return $self->{cons_phast} ;
}

=head2 func

 Get/Set the UCSC functional categories slot

=cut

sub func {
  my $self = shift ;
  $self->{func} = shift if @_ ;
  return $self->{func} ;
}

=head2 note

Field to collect info about the search.

=cut

sub note {
  my $self = shift ;
  $self->{note} = shift if @_ ;
  return $self->{note} ;
}

=head2 _print_data

For debugging purposes.  Print the data structure.

=cut

sub _print_data {
  use Data::Dumper ;

  my $self = shift ;
  print Dumper $self ;
  print "\n\n" ;
}

=head2 _return_data

For debugging purposes.  Return the data structure as a string for
printing elsewhere.  Pass to Log::Log4perl, for instance.

=cut

sub _return_data {
  use Data::Dumper ;

  my $self = shift ;
  return  Dumper $self ;
}

return 1 ;
