package EnsemblAccess;

use strict;
use Log::Log4perl ;

my $VERSION = '0.1.0' ;

=head1 EnsemblAccess

Interface to Ensembl

=head1 Author

Richard T. Guy

=head1 Methods

=head2 new

constructor

=cut

sub new {
  my $log = Log::Log4perl->get_logger("new") ;
  my $msg = "In constructor." ;
  $log->debug($msg) ;

  my $invocant = shift ;
  my $class = ref($invocant) || $invocant ;
  my $self = { } ;
  bless($self, $class) ;
  return $self ;
}

=head2 get_linkage_disequil

Queries Ensembl for linkage disequilibrium data. Updates data->LD_high
if there are any with r^2 > 0.8.

=cut

sub get_linkage_disequil {
  my $log = Log::Log4perl->get_logger("get_linkage_disequil") ;
  my $msg = "In get_linkage_disequil" ;
  $log->debug($msg) ;

  my $self   = shift ;
  my $data   = shift ;
  my $marker = $data->marker ;
  my @transcripts ;
  my %rethash ;

  my $counter = 0 ;
  my $success = 0 ;
  my $limit   = 5 ;

  my %ld_hash ;
  my %ld_cnt ;
  my $ones_count = 0;  # this will keep track of number in perfect LD.
  my %perfect_hash;  # Keeps distance => snp hash for perfect LD snps.
  my %perfect_cnt;   # Keeps number at that distance (almost always 1)

  while ( !$success && $counter < $limit ) {
    eval {

      my $dbVar = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new(
                                                                 -host    => 'ensembldb.ensembl.org',
                                                                 -dbname  => 'homo_sapiens_variation_59_37d',
                                                                 -species => 'homo_sapiens',
                                                                 -group   => 'variation',
                                                                 -user    => 'anonymous',
                                                                 -port    => 5306
                                                                ) ;

      # connect to Core database
      my $dbCore = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                                                       -host    => 'ensembldb.ensembl.org',
                                                       -dbname  => 'homo_sapiens_core_59_37d',
                                                       -species => 'homo_sapiens',
                                                       -group   => 'core',
                                                       -user    => 'anonymous',
                                                       -port    => 5306
                                                      ) ;

      my $va_adaptor = $dbVar->get_VariationAdaptor ; # get the different adaptors for the different objects needed
      my $vf_adaptor = $dbVar->get_VariationFeatureAdaptor ;
      my $ld_adaptor = $dbVar->get_LDFeatureContainerAdaptor ;
      my $var        = $va_adaptor->fetch_by_name($marker) ; # get the Variation from the database using the name

      # some snps like rs28395853 fail to recognize in ensembl and I am just skipping them.
      unless ($var) {
        print "[EnsemblAccess::get_linkage_disequil] Ensembl LD failed to recognize.\n" ;
        $success = 1 ;
        return ;
      }

      foreach my $vf ( @{ $vf_adaptor->fetch_all_by_Variation($var) } ) {
        my $ldContainer = $ld_adaptor->fetch_by_VariationFeature($vf) ;
        foreach my $r_square ( @{ $ldContainer->get_all_r_square_values } ) {
          if ( $r_square->{r2} >= .8 ) {
            if ( $r_square->{variation1}->variation_name eq $marker ) {
              $ld_hash{ $r_square->{r2} } = $r_square->{variation2}->variation_name ;
              $ld_cnt{ $r_square->{r2} }++ ;
            } elsif ( $r_square->{variation2}->variation_name eq $marker ) {
              $ld_hash{ $r_square->{r2} } = $r_square->{variation1}->variation_name ;
              $ld_cnt{ $r_square->{r2} }++ ;
            }
          }
          if ( $r_square->{r2} > 0.2 ) {
            print "[EnsemblAccess::get_linkage_disequil] ",  $r_square->{variation2}->variation_name ;
            print " " . $r_square->{variation1}->variation_name ;
            print " " . $r_square->{r2} ;
            print "\n" ;
          }

          # keep track of number with 1.0000.
          if ( $r_square->{r2} >= 1 ) {
            my $temp_snp ;
            my $foundit = 0 ;
            if ( $r_square->{variation1}->variation_name eq $marker ) {
              $temp_snp = $r_square->{variation2}->variation_name ;
              $foundit++ ;
            } elsif ( $r_square->{variation2}->variation_name eq $marker ) {
              $temp_snp = $r_square->{variation1}->variation_name ;
              $foundit++ ;
            }
            if ($foundit) {
              $ones_count++ ;
              my $temp_pos = get_position_only($temp_snp) ; # This function in NCBIAccess.pm
              $perfect_hash{abs( $data->position - $temp_pos ) } .=
                $temp_snp . "(*) " ;
              $perfect_cnt{ abs( $data->position - $temp_pos ) }++ ;
            }
          }                     # end if r_square
        }                       # end foreach r_square
      }                         # end foreach vf

      $success = 1 ;

    } ;  # end eval

    # Check syntax error message from the eval()
    if ($@) {
      print "[EnsemblAccess::get_linkage_disequil] Ensembl LD died $counter \nMessage: " . $@ ;
      $success = 0 ;
      $counter++ ;
      if ( $counter == 6 ) {
        die "[EnsemblAccess::get_linkage_disequil] error 1: Ensembl LD failed to recognize" ;
      }
      sleep( 5 * $counter ) ;
    }
  } # end while not success

  my $ld_list = "" ;
  my $cntr    = 0 ;
  if ( $ones_count >= 5 ) {

    # Do the special case of 5 in perfect LD.
    for my $ld ( sort keys %perfect_hash ) {
      $ld_list .= $perfect_hash{$ld} . " " ;
      if ( $cntr >= 4 ) {
        last ;
      }
      $cntr += $perfect_cnt{$ld} ;
    }
  } else {
    for my $ld ( reverse sort keys %ld_hash ) {
      $ld_list .= $ld_hash{$ld} ;
      if ( $ld >= 1.0 ) {
        $ld_list .= "(*) " ;
      } else {
        $ld_list .= " " ;
      }
      if ( $cntr >= 4 ) {
        last ;
      }
      $cntr += $ld_cnt{$ld} ;
    }
  }

  $data->LD_high($ld_list) ;

} # end get_linkage_disequil


=head2 get_ensembl_data

Database version 51_36m

Recieves a marker.  Returns a hash of arrays where each array contains
all transcripts for a given gene (keys are genes.)  Fills
data->consequence and data->coding.

=cut

sub get_ensembl_data {
  my $log = Log::Log4perl->get_logger("get_ensembl_data") ;
  my $msg = "In get_ensembl_data" ;
  $log->debug($msg) ;

  my $self   = shift ;
  my $data   = shift ;
  my $marker = $data->marker ;
  my @transcripts ;
  my $ret_str = "" ;

  # connect to Variation database

  my $counter     = 0 ;
  my $success     = 0 ;
  my $limit       = 5 ;
  my $sleep_times = 1 ;
  my %con_hash;               # hash of transcript=> consequence
  my %prot_hash;              # hash of transcript=> protein encoding.

  while ( !$success && $counter < $limit ) {
    eval {
      my $dbVar = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new(
                                                                 -host    => 'ensembldb.ensembl.org',
                                                                 -dbname  => 'homo_sapiens_variation_59_37d',
                                                                 -species => 'homo_sapiens',
                                                                 -group   => 'variation',
                                                                 -user    => 'anonymous',
                                                                 -port    => 5306
                                                                ) ;

      # connect to Core database
      my $dbCore = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                                                       -host    => 'ensembldb.ensembl.org',
                                                       -dbname  => 'homo_sapiens_core_59_37d',
                                                       -species => 'homo_sapiens',
                                                       -group   => 'core',
                                                       -user    => 'anonymous',
                                                       -port    => 5306
                                                      ) ;

      # get the different adaptors for the different objects needed
      my $va_adaptor = $dbVar->get_VariationAdaptor ;
      my $vf_adaptor = $dbVar->get_VariationFeatureAdaptor ;

      # get the Variation from the database using the name
      my $var = $va_adaptor->fetch_by_name($marker) ;

      # Some snps like rs28395853 fail to recognize in ensembl and I am just skipping them.
      unless ($var) {
        $msg = "Ensembl failed to recognize $marker." ;
        $log->debug($msg) ;
        $success = 1 ;
        return "" ;
      }

      foreach my $vf ( @{ $vf_adaptor->fetch_all_by_Variation($var) } ) {
        foreach my $ct ( @{ $vf->get_consequence_type } ) {
          push @transcripts, $ct ;
        }

        my $transcript_variations = $vf->get_all_TranscriptVariations ;
        if ( defined $transcript_variations ) {
          foreach my $tv ( @{$transcript_variations} ) {
            my $tv_name = $tv->transcript->stable_id ;
            $con_hash{$tv_name} = $tv->display_consequence ;
            $prot_hash{$tv_name} = ( $tv->transcript->biotype =~ m/protein_coding/ ) ;
          }
        }
      }

      $va_adaptor = () ;
      $vf_adaptor = () ;
      $var        = () ;

      $success++ ;
    } ; # end eval

    # Check syntax error message from the eval()
    if ($@) {
      $msg = "Ensembl died after $counter tries, Message: " . $@ ;
      $log->info($msg) ;
      print "[EnsemblAccess::get_ensembl_data] Ensembl died after $counter tries, Message: " . $@, "\n" ;
      $success = 0 ;
      $counter++ ;

      sleep( $sleep_times * 4 ) ;
      $sleep_times = 2 * $counter * $sleep_times ;
    }

    if ( $counter >= $limit ) {
      $msg = "Ensembl could not be reached." ;
      $log->info($msg) ;
      warn "[EnsemblAccess::get_ensembl_data] Error 1: Ensembl could not be reached.\n" ;
      last ;
    }

  } # end while not success

  $data->consequence(    {%con_hash} ) ;
  $data->protein_coding( {%prot_hash} ) ;

  if ($log->is_debug) {
    my @str ;
    push @str, "con_hash" ;
    if (defined $data->consequence) {
      foreach my $key (keys %con_hash) {
        push @str, join(":", $key, $con_hash{$key}) ;
      }
    } else {
      push @str, "empty" ;
    }
    $msg = join("|", @str) ;
    $log->debug($msg) ;

    @str = undef ;
    push @str, "prot_hash" ;
    if (defined $data->protein_coding) {
      foreach my $key (keys %prot_hash) {
        push @str, join(":", $key, $prot_hash{$key}) ;
      }
    } else {
      push @str, "empty" ;
    }

    $msg = join("|", @str) ;
    $log->debug($msg) ;

  }

} # end get_ensembl_data

return 1 ;
