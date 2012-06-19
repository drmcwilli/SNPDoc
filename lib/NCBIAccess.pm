package NCBIAccess ;

use strict ;
# use LWP::Simple ;
use LWP::UserAgent ; # so we can check the return codes
use Log::Log4perl ;

my $VERSION = '0.1.0' ;

=pod

=head1 NCBIAccess

Part of the SNPdoc package.  Handles all calls to NCBI.

=head1 Author

Richard T. Guy

=cut

=head1 Methods

=head2 new

Constructor

=cut

my $log = Log::Log4perl->get_logger("NCBIAccess") ;

sub new {
  my $invocant = shift ;
  my $class = ref($invocant) || $invocant ;
  my $self = { } ;
  bless($self, $class) ;
  return $self ;
}



=head2 verbose_level

=cut

sub verbose_level {
  my $self = shift ;
  $self->{verbose} = shift if @_ ;
  return $self->{verbose} ;
}



=head2 get_snpinfo

One of the major access points for NCBI data.

Fills the 'data' hash with: chr, pos, gene (if present), gene info,
gene alias, and the sequence on either side.

This function apparently was replaced with one of the same name in UCSC.pm.

=cut

sub get_snpinfo {
  my $log = Log::Log4perl->get_logger("get_snpinfo") ;
  my $msg = "In get_snpinfo" ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;

  # Load from NCBI.
  # variables used in API for NCBI.
  my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils" ;
  my $db      = "SNP" ;
  my $report  = "DocSet" ;
  my $esearch = "$utils/esearch.fcgi?"
    . "db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfumbc.edu&term=" ;

  my $marker = $data->marker;   # Easier to have a local copy.

  my $Count;
  my $QueryKey ;
  my $WebEnv ;
  my $retstart ;
  my $retmax ;

  my $esearch_result = $self->ncbi_link_retrieve( $esearch . $marker ) ;
  if (!defined $esearch_result) {
    $msg = "Could not execute NCBI esearch for $marker." ;
    $log->warn($msg) ;
  } else {
    $esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s ;
    $Count    = $1 ;
    $QueryKey = $2 ;
    $WebEnv   = $3 ;
    $retstart = 0 ;
    $retmax   = 1 ;
  }

  my $efetch = "$utils/efetch.fcgi?" .
               "rettype=$report&retmode=text&retstart=$retstart&" .
               "retmax=$retmax&db=$db&query_key=$QueryKey&tool=snpdoc&" .
               "email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv" ;

  my $efetch_result = $self->ncbi_link_retrieve($efetch) ;
  if ( !defined($efetch_result) ) {
    $msg = "NCBI failed to return (and failcatch did not work.)" ;
    $log->warn($msg) ;
  }

  #
  # Find chr and chr position.
  #
  my $chr_flag = 0 ;
  if ( $efetch_result =~ m/CHROMOSOME BASE POSITION=([\dXY]+):(\d+)/ ) {
    $chr_flag++ ;
    my $pos = $2; # This is to take care of the one-off problem we had.

    #           $pos++;  # RTG 3-30-2010 Took this back out by request.
    $data->position($pos) ;
    $data->chromosome($1) ;
  } elsif ( $efetch_result =~ m/CHR=Multi/ ) {
    my $note = "NCBI, multiple entries" ;
    if (defined $data->note()) {
      $note = $data->note() . "; " . $note ;
    }
    $data->note($note) ;
  }

  # Find gene, geneid, genefunction.  Here we want to store that information and implant it at the end of the method.
  my $gene         = "" ;
  my $geneid       = "" ;
  my $genefunction = "" ;
  if ( $efetch_result =~ m/GENE/ ) {
    $efetch_result =~ m/GENE=(\S+)\nLOCUS_ID=(\S+)\nFXN_CLASS=(\S+)/ ;
    $gene         = $1 ;
    $geneid       = $2 ;
    $genefunction = $3 ;
    $data->gene($gene); # this is a placeholder and might be changed when we get gene info (sometimes the order is bad compared to gene_id.)
    $data->gene_id($geneid) ;
    $data->gene_fxn($genefunction) ;
  }

  #
  # Finish by building the link.
  #
  $efetch_result =~ m/TAX_ID=(\d+)/ ;
  my $taxid = $1 ;
  if ($chr_flag) {
    $data->Chr_URL(
                   "http://www.ncbi.nlm.nih.gov/mapview/map_search.cgi?taxid="
                   . $taxid
                   . "&query="
                   . $data->marker ) ;
  } else {
    $data->Chr_URL("") ;
  }

  unless ( $data->allele1 ) {

    #
    #  Now we will find the dna sequence.
    #
    $report         = "Brief" ;
    $esearch_result = $self->ncbi_link_retrieve( $esearch . $marker ) ;

    if ( !$esearch_result ) {
      $msg = "Could not execute NCBI esearch for $marker." ;
      $log->warn($msg) ;
    } else {
      $esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s ;
      $Count    = $1 ;
      $QueryKey = $2 ;
      $WebEnv   = $3 ;
      $retstart = 0 ;
      $retmax   = 1 ;
    }
    $efetch =
      "$utils/efetch.fcgi?"
        . "rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&"
          . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv" ;

    # Pretty sure we might just get rid of this?
    $efetch_result = $self->ncbi_link_retrieve($efetch) ;
    if ( !defined($efetch_result) ) {
      $msg = "Could not execute NCBI efetch for $marker" ;
      $log->warn($msg) ;
    }

    # Scrape the line for our dna sequence.

    my @temp0 = split( "\n", $efetch_result ) ;
    shift @temp0 ;
    shift @temp0 ;

    $a = shift @temp0 ;

    my @dnasplit = split( /\[|\]|\//, $a ) ;
    if ( scalar @dnasplit < 4 ) {
      $msg = "Brief summary failed to give sequence." ;
      $log->warn($msg) ;

      $data->dna1("") ;
      $data->allele1("") ;
      $data->dna2("") ;
      $data->allele2("") ;
    } else {
      my $fiveprime  = shift @dnasplit ;
      my $a1         = shift @dnasplit ;
      my $a2         = shift @dnasplit ;
      my $threeprime = shift @dnasplit ;

      # Clean up length to 20.
      $fiveprime  = substr( $fiveprime,  -20, 20 ) ;
      $threeprime = substr( $threeprime, 0,   20 ) ;

      $data->dna1( $fiveprime . $a1 . $threeprime ) ;
      $data->dna2( $fiveprime . $a2 . $threeprime ) ;
      $data->allele1($a1) ;
      $data->allele2($a2) ;
    }
  }

} # end get_snpinfo


=head2 get_sequence_data

Return the sequence data only.  Sets data->all1, all2, dna1, and dna2

The efetch result looks like:

1: rs1263803 [Homo sapiens]
CCAAAAAATACAAAAAATAGTTTGA[C/T]TGGCATGGCTCCTGTTTTCAAAGAG

=cut

sub get_sequence_data {
  my $log = Log::Log4perl->get_logger("get_sequence_data") ;
  my $msg = "In get_sequence_data" ;
  $log->debug($msg) ;

  my $self = shift  ;
  my $data = shift  ;
  my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils"  ;
  my $db      = "SNP"  ;
  my $esearch = "$utils/esearch.fcgi?db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu.edu&term="  ;

  my $marker = $data->marker ;   # easier to have a local copy.

  my $report = "Brief"  ;
  my $Count ;
  my $QueryKey ;
  my $WebEnv ;
  my $retstart ;
  my $retmax ;

  my $esearch_result = $self->ncbi_link_retrieve( $esearch . $marker )  ;
  if ( !$esearch_result ) {
    $msg = "Could not execute NCBI esearch on $marker." ;
    $log->warn($msg) ;
  } else {
    $esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s  ;
    $Count    = $1  ;
    $QueryKey = $2  ;
    $WebEnv   = $3  ;
    $retstart = 0  ;
    $retmax   = 1  ;
  }

  my $efetch =
    "$utils/efetch.fcgi?"
      . "rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&"
        . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv"  ;

  # Pretty sure we might just get rid of this?
  my $efetch_result = $self->ncbi_link_retrieve($efetch)  ;
  if ( !defined($efetch_result) ) {
    $msg = "Could not execute NCBI efetch for $marker." ;
    $log->warn($msg) ;
  }

  # Scrape the line for our dna sequence.

  my @temp0 = split( "\n", $efetch_result )  ;
  shift @temp0  ;
  shift @temp0  ;

  my $a = shift @temp0  ;

  my @dnasplit = split( /\[|\]|\//, $a ) if defined $a ;
  if ( scalar @dnasplit < 4 ) {
    $msg = "Brief summary failed to give sequence for marker $marker." ;
    $log->warn($msg) ;

    $data->dna1("")  ;
    $data->allele1("")  ;
    $data->dna2("")  ;
    $data->allele2("")  ;
  } else {
    my $fiveprime  = shift @dnasplit  ;
    my $a1         = shift @dnasplit  ;
    my $a2         = shift @dnasplit  ;
    my $threeprime = shift @dnasplit  ;

    # Clean up length to 20.
    $fiveprime  = substr( $fiveprime,  -20, 20 )  ;
    $threeprime = substr( $threeprime, 0,   20 )  ;

    $data->dna1( $fiveprime . $a1 . $threeprime )  ;
    $data->dna2( $fiveprime . $a2 . $threeprime )  ;
    $data->allele1($a1)  ;
    $data->allele2($a2)  ;
  }

}  # get_sequence_data

=head2 get_position_only

Fetch the position of a marker from NCBI.

=cut

sub get_position_only {
  my $log = Log::Log4perl->get_logger("get_position_only") ;
  my $msg = "In get_position_only" ;
  $log->debug($msg) ;

  my $self = shift  ;
  my $marker = shift  ;

  # Load from NCBI.
  # variables used in API for NCBI.
  my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils"  ;
  my $db      = "SNP"  ;
  my $report  = "DocSet"  ;
  my $esearch = "$utils/esearch.fcgi?"
    . "db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu&term="  ;

  my $Count ;
  my $QueryKey ;
  my $WebEnv ;
  my $retstart ;
  my $retmax ;
  my $esearch_result = $self->ncbi_link_retrieve( $esearch . $marker )  ;

  if (!defined $esearch_result) {
    $msg = "Could not execute NCBI esearch for $marker." ;
    $log->warn($msg) ;
  } else {
    $esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s  ;
    $Count    = $1  ;
    $QueryKey = $2  ;
    $WebEnv   = $3  ;
    $retstart = 0  ;
    $retmax   = 1  ;
  }

  my $efetch =
    "$utils/efetch.fcgi?"
      . "rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&"
        . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv"  ;

  my $efetch_result = $self->ncbi_link_retrieve($efetch)  ;
  if ( !defined($efetch_result) ) {
    $msg = "Could not execute NCBI efetch for $marker." ;
    $log->warn($msg) ;
    return 0  ;
  }

  #
  # Find position.
  #
  my $chr_flag = 0  ;
  if ( $efetch_result =~ m/CHROMOSOME BASE POSITION=([\dXY]+):(\d+)/ ) {
    $chr_flag++  ;
    my $pos = $2; # This is to take care of the one-off problem we had.
    $pos++  ;
    return $pos  ;
  } else {
    return 0  ;
  }

} # end get_position only.



=head2  get_merged

Find out if the current snp is merged.  Passed a value of the current
snp.  Returns value of merged to if it exists.  If the line <RsLinkout
resourceId="1" linkValue="245246"/> matches the snp passed then no
merge occured.  Otherwise, print the merge (set data->merged and/or
data->merged_here).

Example: rs3811635

=cut

sub get_merged {
  my $log = Log::Log4perl->get_logger("get_merged") ;
  my $msg = "In get_merged." ;
  $log->debug($msg) ;

  my $self    = shift  ;
  my $data    = shift  ;
  my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils"  ;
  my $db      = "SNP"  ;
  my $report  = "XML"  ;
  my $esearch = "$utils/esearch.fcgi?"
    . "db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu&term="  ;

  my $marker    = $data->marker()  ;
  my $this_note = $data->note ;

  my $esearch_result = $self->ncbi_link_retrieve( $esearch . $marker )  ;
  if ( !defined($esearch_result) ) {
    $msg = "Could not execute NCBI esearch for $marker." ;
    $log->warn($msg) ;
  }

  # check for missing
  if ( $esearch_result =~ m/PhraseNotFound/ ) {
    $this_note->{"SNP not found in NCBI database."}++ ;
    # $data->chromosome("SNP not found in NCBI database.")  ;
    ## Obviated by UCSC.  $data->version("N/A")  ;
    return  ;
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

  my $efetch_result = $self->ncbi_link_retrieve($efetch)  ;

  if ( !defined($efetch_result) ) {
    $msg = "Could not execute NCBI efetch for $marker." ;
    $log->warn($msg) ;
  }

  if ( $efetch_result =~ m/linkValue=\D(\d*)/ ) {
    my $efetch_merge = $1  ;

    my $new_marker = "rs" . $efetch_merge ;
    unless ( $new_marker eq $data->marker ) {
      $data->merged_to($new_marker) ;
      my $txt = join(" ", $marker, "merged to", $new_marker) ;
      $this_note->{$txt}++ ;
      if ($self->{verbose}) {
        print "[NCBIAcess::get_merged] ", $data->marker_text, "\n"  ;
      }
    }
  }

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
    $data->merged_here($merge_list)  ;
  }

} # end get_merged.



=head2 get_gene

Get gene from api.  Returns: nothing, but updates name, desc, and
alias for the geneid.  Each as a string.

=cut

sub get_gene {
  my $log = Log::Log4perl->get_logger("get_gene") ;
  my $msg = "In get_gene." ;
  $log->debug($msg) ;

  my $self = shift ;

  my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils" ;
  my $db      = "gene" ;
  my $report  = "DocSum" ;
  my $esearch = "$utils/esearch.fcgi?db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu&term=term=human[organism]+" ;
  my $gene  = shift ;
  my $data    = shift ;

  my $descr     = $data->description; # save so we can append.
  my $alias_old = $data->alias ;

  my $esearch_result = $self->ncbi_link_retrieve( $esearch . $gene ) ;
  if (!defined $esearch_result) {
    $msg = "Could not execute NCBI esearch for $gene." ;
    $log->warn($msg) ;
  }
  $esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s ;

  my $Count    = $1 ;
  my $QueryKey = $2 ;
  my $WebEnv   = $3 ;
  my $retstart = 0 ;
  my $retmax   = 1 ;
  my $efetch =
    "$utils/efetch.fcgi?"
      . "rettype=$report&retmode=xml&retstart=$retstart&retmax=$retmax&"
        . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv" ;

  my $efetch_result = $self->ncbi_link_retrieve($efetch) ;
  if ( !defined($efetch_result) ) {
    $msg = "Could not execute NCBI efetch for $gene." ;
    $log->warn($msg) ;
  }

  my $temp1;                    # temp var used a couple times.

  # align name with this symbol.
  if ( $efetch_result =~ /<Gene-ref_locus>(.*)<\/Gene-ref_locus>/ ) {
    $temp1 = $1 ;
  }

  #get name.
  if ( $efetch_result =~ m/<Gene-ref_desc>(.*)<\/Gene-ref_desc>/ ) {
    $temp1 = $1 ;
    $data->description( $descr . $temp1 . "; " ) ;
  } else {
    $data->description( $descr . " Unavailable; " ) ;
  }

  #get aliases
  my $alias ;
  if ( $efetch_result =~ /<Gene-ref_syn>(.*)<\/Gene-ref_syn>/s ) { #the s handles \n.#
    $alias = $1 ;
    chomp $alias ;
    $alias =~ s/\s*<Gene-ref_syn_E>//g ;
    $alias =~ s/<\/Gene-ref_syn_E>\n*/,/g ;
    $alias =~ s/[,\s]*$// ;
    $data->alias( $alias_old . $alias . "; " ) ;
  } else {
    $data->alias("") ;
  }
  return ;
}                               # get_gene



=head2 get_gene_alias

Use NCBI API to get only the gene alias.

=cut

sub get_gene_alias {
  my $log = Log::Log4perl->get_logger("get_gene_alias") ;
  my $msg = "In get_gene_alias." ;
  $log->debug($msg) ;

  my $self = shift  ;

  my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils"  ;
  my $db      = "gene"  ;
  my $report  = "DocSum"  ;
  my $esearch = "$utils/esearch.fcgi?db=$db&retmax=1&usehistory=y&tool=snpdoc&email=dmcwilli\@wfubmc.edu&term=human[organism]+"  ;
  my $gene    = shift  ;
  my $data    = shift  ;

  my $alias_old = $data->alias  ;

  my $esearch_result = $self->ncbi_link_retrieve( $esearch . $gene )  ;
  if (!defined $esearch_result) {
    $msg = "Could not execute NCBI esearch for $gene." ;
    $log->warn($msg) ;
  }
  $esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s  ;

  my $Count    = $1  ;
  my $QueryKey = $2  ;
  my $WebEnv   = $3  ;
  my $retstart = 0  ;
  my $retmax   = 1  ;
  my $efetch =
    "$utils/efetch.fcgi?"
      . "rettype=$report&retmode=xml&retstart=$retstart&retmax=$retmax&"
        . "db=$db&query_key=$QueryKey&tool=snpdoc&email=dmcwilli\@wfubmc.edu&WebEnv=$WebEnv"  ;

  my $efetch_result = $self->ncbi_link_retrieve($efetch)  ;
  if ( !defined($efetch_result) ) {
    $msg = "Could not execute NCBI efetch for $gene." ;
    $log->warn($msg) ;
  }

  #get aliases
  my $alias  ;
  if ( $efetch_result =~ /<Gene-ref_syn>(.*)<\/Gene-ref_syn>/s ) { # The s handles \n.#
    $alias = $1  ;
    chomp $alias  ;
    $alias =~ s/\s*<Gene-ref_syn_E>//g  ;
    $alias =~ s/<\/Gene-ref_syn_E>\n*/,/g  ;
    $alias =~ s/[,\s]*$//  ;
    $data->alias( $alias_old . $alias . "; " )  ;
  } else {
    $data->alias("")  ;
  }
  return  ;
}  # end get_gene_alias


=head2 ncbi_link_retrieve

Handle connection in choppy web environment.

=cut

sub ncbi_link_retrieve {
  my $log = Log::Log4perl->get_logger("ncbi_link_retrieve") ;
  my $msg = "In ncbi_link_retrieve." ;
  $log->debug($msg) ;

  my $self = shift  ;
  my $efetch = shift  ;

  my $fetch_result = "NA" ;  # Return something, let the caller check
  my $wait_time = 180 ;      # This is the LWP::UserAgent default, but be explicit

  my $ua = LWP::UserAgent->new() ;
  $ua->timeout($wait_time) ;

  my $result = $ua->get($efetch) ;
  if ($result->code() =~ m/^5/) {
    $msg = "Error accessing NCBI: " . $result->status_line() ;
    $log->warn($msg) ;
  } elsif ($result->code() =~ m/^4/) {
    my $client_error ;
    if ($result->content() =~m|<h2>Error occurred: (.+)</h2>|) {
      $client_error = $1 ;
    }
    $msg = join(" ", "Problem accessing NCBI:", $result->status_line(), $client_error) ;
    $log->warn($msg) ;
  } else {
    $fetch_result = $result->content() ;
  }

  return $fetch_result  ;
} # end ncbi_link_retrieve

return 1 ;
