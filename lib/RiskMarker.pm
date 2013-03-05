package RiskMarker ;

use LWP::Simple ;
use Log::Log4perl ;
use Data::Dumper ;

=head1 Risk Marker

Calculate the risk for a marker using information from external
databases.

=head1 Author

Richard T. Guy and Wei Wang

=head1 Methods

=head2 calc_risk

 Calculate risk using FASTSNP algorithm.  Fill data->risk and
 data->classification.

 Original algorithm using the Ensembl functional categories.

=cut

sub calc_risk {
  my $log = Log::Log4perl->get_logger("calc_risk") ;
  my $msg = "In calc_risk" ;
  $log->debug($msg) ;

  shift ;
  $verbose = shift ;
  my $data = shift;             # Holds a SNPData.pm object.

  my %con_hash  = %{$data->consequence} ;
  my %prot_hash = %{$data->protein_coding} ;

  my $marker = $data->marker ;
  $dna1 = $data->dna1 ;
  $dna2 = $data->dna2 ;

  my $maxrisk = 0 ; my $maxclass = "" ;
  my $risk ; my $classification ;
  my $fxn ;                      # Holds each transcript function.
  my $tf_ct1   = -1 ; my $tf_ct2   = -1 ;
  my $rese_ct1 = -1 ; my $rese_ct2 = -1 ;
  my $esef_ct1 = -1 ; my $esef_ct2 = -1 ;
  my $fas_ct1  = -1 ; my $fas_ct2  = -1 ;

  foreach my $tran (keys %con_hash) {
    $fxn = $con_hash{$tran} ;
    $msg = "Iterating con_hash; transcript: $tran, function: $fxn" ;
    $log->debug($msg) ;

    if ($verbose) {
      print "[RiskMarker::calc_risk] Transcript: $tran, Function: " . $fxn . "\n" ;
    }

    # First handle the simple cases.
    if ($fxn =~ m/^INTERGENIC/) {
      $risk = 0 ;
      $classification = "Intergenic" ;
    } elsif ($fxn =~ m/STOP_GAINED/) {
      $risk = 5 ;
      $classification = "Stop Gained" ;
    } elsif ($fxn =~ m/STOP_LOST/) {
      $risk = 5 ;
      $classification = "Stop Lost" ;
    } elsif ($fxn =~ m/SPLICE_SITE/) {
      $risk = 3 ;
      $classification = "Splice Site" ;
    } else {
      # Now handle the cases the will require a data load from LWP::Simple.
      # First several require only TFSEARCH.
      if ($tf_ct1 < 0) {
        # ($tf_ct1, $tf_ct2) = get_TFSEARCH() ;
        $tf_result = get_TFSEARCH() ;
        if (!$tf_result->{status}) {
          $msg = "[RiskMarker::calc_risk] Could not reach TFSEARCH db; cannot calculate risk." ;
          $log->warn($msg) ;
          last FUNCTION ;
        } else {
          $tf_ct1 = $tf_result->{tf1} ;
          $tf_ct2 = $tf_result->{tf2} ;
        }
      }

      if ($fxn =~ m/^INTRONIC$/ ) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0; $classification = "Intronic With No Known Function" ;
        } else {
          $risk = 3; $classification = "Intronic Enhancer" ;
        }
      } elsif ($fxn =~ m/^3PRIME_UTR$/ ) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0; $classification = "Downstream With No Known Function" ;
        } else {
          $risk = 3; $classification = "Promoter/Regulatory Region" ;
        }
      } elsif ($fxn =~ m/^5PRIME_UTR$/ ) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0; $classification = "Upstream With No Known Function" ;
        } else {
          $risk = 3; $classification = "Promoter/Regulatory Region" ;
        }
      } elsif ($fxn =~ m/^UPSTREAM$/ ) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0; $classification = "Upstream With No Known Function" ;
        } else {
          $risk = 3; $classification = "Promoter/Regulatory Region" ;
        }
      } elsif ($fxn =~ m/^DOWNSTREAM$/ ) {
        $risk = 0; $classification = "Downstream With No Known Function" ;
      } else {           # WE MIGHT WANT TO MAKE THIS LIKE UPSTREAM...

        # We are only testing for EQUALITY between each of these three
        # counts.  Therefore, I exit as soon as I detect inequality.
        # This should drastically reduce number of calls.
        if ($esef_ct1 < 0) {
          ($esef_ct1, $esef_ct2) = get_ESEF($dna1, $dna2) ;
          if ($esef_ct1 != $esef_ct2) {
            $rese_ct1 = 1; $rese_ct2 = -1 ;
            $fas_ct2  = 1;  $fas_ct2 = -1 ;
          } else {
            ($rese_ct1, $rese_ct2) = get_rescueese_data() ;
            if ($rese_ct1 != $rese_ct2) {
              $fas_ct1 = 1; $fas_ct2 = -1 ;
            } else {
              ($fas_ct1, $fas_ct2) = get_FASESE() ;
            }
          }
        }

        # Now, we will continue risk assessment.
        if ($fxn =~ m/^SYNONYMOUS_CODING$/ ) {
          if (    $esef_ct1 == $esef_ct2
               && $rese_ct1 == $rese_ct2
               && $fas_ct1  == $fas_ct2 ) {
            $risk = 1 ;
            $classification = "Sense/Synonymous" ;
          } else {
            $risk = 3 ;
            $classification = "Sense/Synonymous; Splicing Regulation" ;
          }
        } elsif ( $fxn =~ m/^NON_SYNONYMOUS_CODING$/ ) {

          # We need to get transcript information from ensembl.  Requires ESE0000foo numbers.
          my $proteins = $prot_hash{$tran} ;

          if ( $proteins > 0 ) {
            if ( $esef_ct1 == $esef_ct2 && $rese_ct1 == $rese_ct2 && $fas_ct1 == $fas_ct2 ) {
              $risk = 4 ;
              $classification = "Mis-Sense (Leading to Non-Conservative Change)" ;
            } else {
              $risk = 4 ;
              $classification = "Mis-Sense (Splicing Regulation, Protein Domain Abolished)" ;
            }
          } else {
            if ( $esef_ct1 == $esef_ct2 && $rese_ct1 == $rese_ct2 && $fas_ct1 == $fas_ct2 ) {
              $risk = 3 ;
              $classification = "Mis-Sense (Leading to Conservative Change)" ;
            } else {
              $risk = 3 ;
              $classification = "Mis-Sense (Conservative); Splicing Regulation" ;
            }
          }

        } else {                # probably could change this...
          $msg = "Ensembl transcript function $fxn not recognized for marker $marker." ;
          $log->info($marker) ;
          warn "[RiskMarker::calc_risk] Error 1: $msg\n" ;
          # $risk = "NA" ;
          $classification = "Unknown: $fxn" ;
        }
      }   # end middle else: functions with TFSEARCH data requirements.
    }     # end outer else: functions with data load requirements.
    if ($verbose) {
      print "[RiskMarker::calc_risk] RISK: $risk - $classification\n" ;
    }
    if ( $risk >= $maxrisk ) {
      $maxrisk  = $risk ;
      $maxclass = $classification ;
    }
  } # end foreach tran

  unless ($maxclass) {
    $maxclass = "NA" ;
  }
  if ($maxclass =~ m/Unknown:/) {
    $maxrisk = "NA" ;
  }
  if ($verbose) {
    print "MAX RISK: $maxrisk - $maxclass\n" ;
  }
  $data->risk($maxrisk) ;
  $data->classification($maxclass) ;

}  # end calc_risk_original


=head2 calc_risk_ucsc

  Adapt the FastSNP algorithm to use the functional categories
  returned by UCSC.

  16-Nov-2011

=cut

sub calc_risk_ucsc {
  my $log = Log::Log4perl->get_logger("calc_risk_ucsc") ;
  my $msg = "In calc_risk_ucsc" ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;

  my $funx = $data->func ;

  my $in_gene = 0 ;
  if ((defined $data->gene) && (length $data->gene > 0)) {
    $in_gene++ ;
  } elsif (grep {/intron/} @funx) {
    $in_gene++ ;
  } elsif (grep {/untranslated/} @funx) {
    $in_gene++ ;
  } elsif (grep {/missense/} @funx) {
    $in_gene++ ;
  }

  my $marker = $data->marker ;
  my $dna1   = $data->dna1 ;
  my $dna2   = $data->dna2 ;


  my $maxrisk  = 0 ;
  my $maxclass = "" ;
  my $risk ;
  my $classification ;
  my $fxn ;                     # Holds each transcript function.

  my $tf_ct1   = -1 ;           # Transcription factor count
  my $tf_ct2   = -1 ;
  my $rese_ct1 = -1 ;           # Splicing enhancer count (RESCUE-ESE)
  my $rese_ct2 = -1 ;
  my $esef_ct1 = -1 ;           # Exonic splicing enhancer count
  my $esef_ct2 = -1 ;
  my $fas_ct1  = -1 ;           # Splicing silencer count (FAS-ESS)
  my $fas_ct2  = -1 ;

 FUNCTION:
  foreach my $func (@{$funx}) {
    $msg = "Interating over functions: func = $func." ;
    $log->debug($msg) ;

    if ($func =~ m/nonsense/) {
      $risk = 5 ;
      $classification = "Stop gained" ;
    } elsif ($func =~ m/stop-lost/) {
      $risk = 5 ;
      $classification = "Stop lost" ;
    } elsif ($func =~ m/splice/) {
      $risk = 3 ;
      $classification = "Splice site" ;
    } else {

      # Get the number of transcription factors for each allele
      if ($tf_ct1 < 0) {
        # ($tf_ct1, $tf_ct2) = get_TFSEARCH() ;

        my $msg = "Just before call to get_tfsearch: dna1 = $dna1; dna2 = $dna2." ;
        $log->debug($msg) ;

        $tf_result = get_TFSEARCH($dna1, $dna2) ;

        if ($log->is_debug()) {
          $msg = "Result of get_TFSEARCH: " . Dumper $tf_result ;
          $log->debug($msg) ;
        }

        if (!$tf_result->{status}) {
          $msg = "[RiskMarker::calc_risk_ucsc] Could not reach TFSEARCH db; cannot calculate risk." ;
          $log->debug($msg) ;
          last FUNCTION ;
        } else {
          $tf_ct1 = $tf_result->{tf1} ;
          $tf_ct2 = $tf_result->{tf2} ;
        }
      }

      if ($func =~ m/intron/) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0 ;
          $classification = "Intronic, no known function" ;
        } else {
          $risk = 3 ;
          $classification = "Intronic enhancer" ;
        }
      } elsif ($func =~ m/untranslated-3/) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0 ;
          $classification = "Downstream, no known function" ;
        } else {
          $risk = 3 ;
          $classification = "Promoter/regulatory region" ; # [drm] this does not make sense to me
        }
      } elsif ($func =~ m/near-gene-3/) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0 ;
          $classification = "Downstream, no known function" ;
        } else {
          $risk = 3 ;
          $classification = "Promoter/regulatory region" ; # [drm] this does not make sense to me
        }
      } elsif ($func =~ m/untranslated-5/) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0 ;
          $classification = "Upstream, no known function" ;
        } else {
          $risk = 3 ;
          $classification = "Promoter/regulatory region" ;
        }
      } elsif ($func =~ m/near-gene-5/) {
        if ($tf_ct1 == $tf_ct2) {
          $risk = 0 ;
          $classification = "Upstream, no known function" ;
        } else {
          $risk = 3 ;
          $classification = "Promoter/regulatory region" ;
        }
      } else {                  # Check for other regulatory features
        if ($esef_ct1 < 0) {
          ($esef_ct1, $esef_ct2) = get_ESEF($dna1, $dna2) ;
          if ($esef_ct1 != $esef_ct2) {
            $rese_ct1 = 1; $rese_ct2 = -1 ;
            $fas_ct2  = 1;  $fas_ct2 = -1 ;
          } else {
            ($rese_ct1, $rese_ct2) = get_rescueese_data($dna1, $dna2) ;
            if ($rese_ct1 != $rese_ct2) {
              $fas_ct1 = 1; $fas_ct2 = -1 ;
            } else {
              ($fas_ct1, $fas_ct2) = get_FASESE($dna1, $dna2) ;
            }
          }
        } # end if esef_ct1

        if ($func =~ m/coding-synon/) {
          if ( $esef_ct1 == $esef_ct2 &&
               $rese_ct1 == $rese_ct2 &&
               $fas_ct1  == $fas_ct2 ) {
            $risk = 1 ;
            $classification = "Sense/synonymous" ;
          } else {
            $risk = 3 ;
            $classification = "Sense/synonymous; splicing regulation" ;
          }
        } elsif ($func =~ m/missense/) {

          if ( $in_gene > 0 ) {
            if ( $esef_ct1 == $esef_ct2 && $rese_ct1 == $rese_ct2 && $fas_ct1 == $fas_ct2 ) {
              $risk = 4 ;
              $classification = "Mis-sense, non-conservative change" ;
            } else {
              $risk = 4 ;
              $classification = "Mis-sense, splicing regulation or protein domain abolished" ;
            }
          } else {
            if ( $esef_ct1 == $esef_ct2 && $rese_ct1 == $rese_ct2 && $fas_ct1 == $fas_ct2 ) {
              $risk = 3 ;
              $classification = "Mis-sense to conservative change" ;
            } else {
              $risk = 3 ;
              $classification = "Mis-sense, conservative change or splicing regulation" ;
            }
          }

        } else {
          $msg = "Did not recognize classification: " . $func ;
          $log->info($msg) ;
          $classification = "Unknown: $func" ;
        }
       } # end middle else: functions with TFSEARCH requirements
    } # end outer else: functions with data load requirements

    if ((defined $risk) &&
        ($risk >= $maxrisk)) {
      $maxrisk  = $risk ;
      $maxclass = $classification ;
    }

  } # end foreach func

  if (!defined $risk) {
    $maxrisk = "NA" ;
  }

  unless ($maxclass) {
    $maxclass = "NA" ;
  }

  if ($maxclass =~ m/Unknown:/) {
    $maxrisk = "NA" ;
  }

  $data->risk_ucsc($maxrisk) ;
  $data->classification_ucsc($maxclass) ;

} #end calc_risk_ucsc

=head2 get_TFSEARCH

  Search www.cbrc.jp and return status and the number of TF found (if
  the search succeeds).  Refers to variables $dna1 and $dna2 set
  previously in calc_risk.  These are alleles 1 and 2 of the SNP, with
  20bp upstream and 20bp downstream.

=cut

# 28-Jun-2012 Return status instead of dieing if cbrc cannot be
# reached.

sub get_TFSEARCH {
  my $log = Log::Log4perl->get_logger("get_TFSEARCH") ;
  my $msg = "In get_TFSEARCH." ;
  $log->debug($msg) ;

  my $dna1 = shift ;
  my $dna2 = shift ;

  my @in1; my @in2 ;
  my $in1; my $in2 ;

  my $retry_cnt1 = 0 ; my $retry_cnt2 = 0 ;
  my $retry_lim  = 5 ;
  my $sleeptime  = 5 ;
  my $passed1    = 0 ; my $passed2 = 0 ;

  my $result = {status =>  0,
                tf1    => -1,
                tf2    => -1} ;


  # my $tf_url = "http://www.cbrc.jp/htbin/nph-tfsearch?label=&seq=" ;   # pre 01-Jul-2012
  my $tf_url = "http://mbs.cbrc.jp/htbin/nph-tfsearch?taxonomy=V&seq=" ;

  # Get 1
  until ($passed1) {
    my $tf1_query = $tf_url . $dna1 ;

    $in1 = get($tf1_query) ;    # HTTP GET from LWP

    unless (defined $in1) {
      $retry_cnt1++ ;

      if ($retry_cnt1 == $retry_lim) {
        $msg = "[RiskMarker::get_TFSEARCH] Website for TFSearch could not be reached.";
        $log->warn($msg) ;

        return $result ;
      }

      my $sleep = $sleeptime * $retry_cnt1 ;
      $msg = "TFSearch1 was unavailable on try $retry_cnt1 of $retry_lim.  Hibernating for $sleep seconds." ;
      $log->info($msg) ;
      print "[RiskMarker::get_TFSEARCH] TFSearch1 was unavailable on try $retry_cnt1 of $retry_lim.  Hibernating for $sleep seconds.\n" ;
      sleep($sleep) ;
    } else {
      $passed1++;
    }
  }
  @in1 = split(/\n/, $in1) ;

  # Get 2
  until ($passed2) {
    my $tf2_query = $tf_url . $dna2  ;
    $in2 = get($tf2_query) ;
    unless( defined $in2) {
      $retry_cnt2++ ;

      if ($retry_cnt1 == $retry_lim) {
        $msg = "[RiskMarker::get_TFSEARCH] Website for TFSearch could not be reached.";
        $log->warn($msg) ;

        return $result ;
      }

      my $sleep = $sleeptime*$retry_cnt2 ;

      $msg = "TFSearch2 was unavailable on try $retry_cnt2 of $retry_lim.  Hibernate for $sleep seconds and try again." ;
      $log->info($msg) ;

      print "[RiskMarker::get_TFSEARCH] TFSearch2 was unavailable on try $retry_cnt2 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again.\n" ;
      sleep($sleep) ;
    } else {
      $passed2++;
    }
  }
  @in2 = split(/\n/,$in2) ;

  # The rest of this method written by Wei Wang.
  my $ct1 = 0 ;
  foreach (@in1) {
    if ( $_ =~ m/HREF=http:\/\/www\.cbrc\.jp\/htbin/ ) {
      chomp($_) ;
      $_ =~ s/&lt;/</ ;
      if ( substr( $_, 27, 1 ) ne " " ) {
        $ct1++;
      }
    }
  }

  my $ct2 = 0 ;
  foreach (@in2) {
    if ( $_ =~ m/HREF=http:\/\/www\.cbrc\.jp\/htbin/ ) {
      chomp($_) ;
      $_ =~ s/&lt;/</ ;
      if ( substr( $_, 27, 1 ) ne " " ) {
        $ct2++;
      }
    }
  }

  if ($verbose) {
    print "[RiskMarker::get_TFSEARCH] TFSearch\t$ct1 =[]= $ct2\n" ;
  }

  $result->{status} = 1 ;
  $result->{tf1}    = $ct1 ;
  $result->{tf2}    = $ct2 ;

  return $result ;

} # end get_TFSEARCH

=head2 get_ESEF

Get Exonic splicing enhancer info from rulai.cshl.edu .

=cut

sub get_ESEF {
  my $log = Log::Log4perl->get_logger("get_ESEF") ;
  my $msg = "In get_ESEF." ;
  $log->debug($msg) ;

  my $dna1 = shift ;
  my $dna2 = shift ;

  $msg = "dna1:|" . $dna1 . "| dna2: |" . $dna2 . "|" ;
  $log->debug($msg) ;

  my @in1; my @in2 ;
  my $in1; my $in2 ;

  my $retry_cnt1 = 0 ; my $retry_cnt2 = 0 ;
  my $retry_lim  = 5 ;
  my $sleeptime  = 5 ;
  my $passed1    = 0 ; my $passed2 = 0 ;

  #get 1
  until ($passed1) {
    my $esef1 = "http://rulai.cshl.edu/cgi-bin/tools/ESE/esefinder.cgi?radio_srp40=0&custthresh_srp40=0&name=Send&radio_sf2=0&sequence="
      . $dna1
        . "&custthresh_sc35=0&custthresh_sf2=0&radio_srp55=0&custthresh_srp55=0&protein4=1&email=&protein3=1&protein2=1&protein1=1&radio_sc35=0&upload=" ;

    $msg = "Calling get with url: |" . $esef1 . "|." ;
    $log->debug($msg) ;

    $in1 = get($esef1) ;

    unless(defined $in1) {
      $retry_cnt1++ ;
      $msg = "ESEF1 was unable to be revived." ;
      $log->warn($msg) ;
      die($msg) if ($retry_cnt1 == $retry_lim) ;
      my $sleep = $sleeptime * $retry_cnt1 ;
      $msg = "[RiskMarker::get_ESEF] ESEF1 was unavailable on try $retry_cnt1 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again." ;
      $log->debug($msg) ;
      print $msg, "\n" ;
      sleep($sleep) ;
    } else {
      $passed1++ ;
    }
  }
  @in1 = split(/\n/,$in1) ;

  $msg = "Array in1: |" . join("|", @in1) . "|." ;
  $log->debug($msg) ;

  until ($passed2) {
    my $esef2 = "http://rulai.cshl.edu/cgi-bin/tools/ESE/esefinder.cgi?radio_srp40=0&custthresh_srp40=0&name=Send&radio_sf2=0&sequence="
      . $dna2
        . "&custthresh_sc35=0&custthresh_sf2=0&radio_srp55=0&custthresh_srp55=0&protein4=1&email=&protein3=1&protein2=1&protein1=1&radio_sc35=0&upload=" ;

    $msg = "Calling get with url: |" . $esef2 . "|." ;
    $log->debug($msg) ;

    $in2= get($esef2) ;

    unless(defined $in2) {
      $retry_cnt2++ ;
      $msg = "ESEF2 was unable to be revived." ;
      $log->warn($msg) ;
      die($msg) if ($retry_cnt2 == $retry_lim) ;
      my $sleep = $sleeptime * $retry_cnt2 ;
      $msg = "[RiskMarker::get_ESEF] ESEF2 was unavailable on try $retry_cnt2 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again." ;
      $log->debug($msg) ;
      print $msg, "\n" ;
      sleep($sleep) ;
    } else {
      $passed2++ ;
    }
  }
  @in2 = split(/\n/,$in2) ;

  $msg = "Array in2: |" . join("|", @in2) . "|." ;
  $log->debug($msg) ;

  # The rest of this method written by Wei Wang.

  ### Allele 1 ###
  my $ct1 = 0 ;
  my $temp ;
  my @temps      = () ;
  my @positions1 = () ;
  my @sequences1 = () ;
  my @scores1    = () ;
  foreach (@in1) {
    if ( $_ =~ m/^align=center bgcolor=#FFFF99/ ) {
      chomp($_) ;
      while ( $_ =~ m/navy/ ) {
        ## for positions ##
        $_ = substr( $_, index( $_, 'navy' ) + 5, ) ; ### cuts out old section ###
        $temp = substr( $_, 0, index( $_, '</font>' ) ) ;
        @temps = split( /<br>/, $temp ) ;
        pop(@temps) ;
        foreach my $var (@temps) {
          push @positions1, $var ;
        }
        ## for sequences ##
        $_ = substr( $_, index( $_, 'navy' ) + 5, ) ; ### cuts out old section ###
        $temp = substr( $_, 0, index( $_, '</font>' ) ) ;
        @temps = split( /<br>/, $temp ) ;
        pop(@temps) ;
        foreach my $var (@temps) {
          push @sequences1, $var ;
        }
        ## for sequences ##
        $_ = substr( $_, index( $_, 'navy' ) + 5, ) ; ### cuts out old section ###
        $temp = substr( $_, 0, index( $_, '</font>' ) ) ;
        @temps = split( /<br>/, $temp ) ;
        pop(@temps) ;
        foreach my $var (@temps) {
          push @scores1, $var ;
        }
      }                         # end while navy
    }                           # end if align
  }                             # end foreach in1

  if ( !( @positions1 == @sequences1 && @positions1 == @scores1 ) ) {
    $msg = "[RiskMarker::get_ESEF] Inequality in esef1 results." ;
    $log->warn($msg) ;
    print $msg, "\n" ;
    exit ;
  }

  for ( my $j = 0 ; $j < @positions1 ; $j++ ) {
    if ( $positions1[$j] <= 21
         && ( $positions1[$j] + length( $sequences1[$j] ) ) >= 21 ) {
      $ct1++ ;
    }
  }

  ### Allele 2 ###
  my $ct2 = 0 ;
  $temp  = "" ;
  @temps = () ;
  my @positions2 = () ;
  my @sequences2 = () ;
  my @scores2    = () ;
  foreach (@in2) {

    if ( $_ =~ m/^align=center bgcolor=#FFFF99/ ) {
      chomp($_) ;
      while ( $_ =~ m/navy/ ) {
        ## for positions ##
        $_ = substr( $_, index( $_, 'navy' ) + 5, ) ; ### cuts out old section ###
        $temp = substr( $_, 0, index( $_, '</font>' ) ) ;
        @temps = split( /<br>/, $temp ) ;
        pop(@temps) ;
        foreach my $var (@temps) {
          push @positions2, $var ;
        }
        ## for sequences ##
        $_ = substr( $_, index( $_, 'navy' ) + 5, ) ; ### cuts out old section ###
        $temp = substr( $_, 0, index( $_, '</font>' ) ) ;
        @temps = split( /<br>/, $temp ) ;
        pop(@temps) ;
        foreach my $var (@temps) {
          push @sequences2, $var ;
        }
        ## for sequences ##
        $_ = substr( $_, index( $_, 'navy' ) + 5, ) ; ### cuts out old section ###
        $temp = substr( $_, 0, index( $_, '</font>' ) ) ;
        @temps = split( /<br>/, $temp ) ;
        pop(@temps) ;
        foreach my $var (@temps) {
          push @scores2, $var ;
        }
      }                         # end while navy
    }                           # end if align
  }                             # end foreach in2

  if ( !( @positions2 == @sequences2 && @positions2 == @scores2 ) ) {
    $msg = "[RiskMarker::get_ESEF] Inequality in esef2 results." ;
    $log->warn($msg) ;
    print $msg, "\n" ;
    exit ;
  }

  for ( my $j = 0 ; $j < @positions2 ; $j++ ) {
    if ( ($positions2[$j] <= 21) &&
         ($positions2[$j] + length( $sequences2[$j] ) >= 21) ) {
      $ct2++ ;
    }
  }
  $msg = "ct1 = $ct1; ct2 = $ct2" ;
  $log->debug($msg) ;

  print "[RiskMarker::get_ESEF] ESEfinder\t$ct1 =[]= $ct2\n" if($verbose) ;

  return $ct1, $ct2 ;

} # end get_ESEF

=head2 get_rescuesse_data

  Fetch exonic splicing enhancer information from the RESCUE-ESE site at
  genes.mit.edu

=cut

sub get_rescueese_data {
  my $log = Log::Log4perl->get_logger("get_rescueese_data") ;
  my $msg = "In get_rescueese_data." ;
  $log->debug($msg) ;

  my $dna1 = shift ;
  my $dna2 = shift ;

  my @in1; my @in2 ;
  my $in1; my $in2 ;

  my $retry_cnt1 = 0 ; my $retry_cnt2 = 0 ;
  my $retry_lim  = 5 ;
  my $sleeptime  = 5 ;
  my $passed1    = 0 ; my $passed2 = 0 ;

  my $rese1 = "http://genes.mit.edu/cgi-bin/rescue-ese_new.pl?&Human=1&process=true&sequence="
    . $dna1 ;
  my $rese2 = "http://genes.mit.edu/cgi-bin/rescue-ese_new.pl?&Human=1&process=true&sequence="
    . $dna2 ;

  until ($passed1) {
    $in1 = get($rese1) ;

    unless(defined $in1) {
      $retry_cnt1++ ;
      die("RESE1 was unable to be revived.") if ($retry_cnt1 == $retry_lim) ;
      my $sleep = $sleeptime * $retry_cnt1 ;
      print "[RiskMarker::get_rescueese_data] RESE1 was unavailable on try $retry_cnt1 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again.\n" ;
      sleep($sleep) ;
    } else {
      $passed1++  ;
    }
  }
  @in1 = split(/\n/,$in1) ;

  until ($passed2) {
    $in2 = get($rese2) ;

    unless(defined $in2) {
      $retry_cnt1++ ;
      die("RESE2 was unable to be revived.") if ($retry_cnt2 == $retry_lim) ;
      my $sleep = $sleeptime * $retry_cnt2 ;
      print "[RiskMarker::get_rescueese_data] RESE2 was unavailable on try $retry_cnt2 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again.\n" ;
      sleep($sleep) ;
    } else {
      $passed2++  ;
    }
  }
  @in2 = split(/\n/,$in2) ;

  # The rest of this method written by Wei Wang.

  my $ct1 = 0 ;
  foreach (@in1) {
    if ( $_ =~ m/class="eseRow"/ ) {
      chomp($_) ;
      $_ =~ s/<span class="eseRow">// ;
      $_ =~ s/<\/span>// ;
      if ( length($_) < 21 ) {
        next ;
      }
      if ( substr( $_, 20, 1 ) ne " " ) {
        $ct1++ ;
      }
    }
  }

  my $ct2 = 0 ;
  foreach (@in2) {
    if ( $_ =~ m/class="eseRow"/ ) {
      chomp($_) ;
      $_ =~ s/<span class="eseRow">// ;
      $_ =~ s/<\/span>// ;
      if ( length($_) < 21 ) {
        next ;
      }
      if ( substr( $_, 20, 1 ) ne " " ) {
        $ct2++ ;
      }
    }
  }

  print "[RiskMarker::get_rescueese_data] Rescue-ESE\t$ct1 =[]= $ct2\n"  if ($verbose) ;

  return $ct1, $ct2 ;

} # end get_rescueese_data

=head2 get_FASESE

 Fetch exonic splicing silencer information from the FAS-ESS site at
 genes.mit.edu.

=cut

sub get_FASESE {
  my $log = Log::Log4perl->get_logger("get_FASESE") ;
  my $msg = "In get_FASESE." ;
  $log->debug($msg) ;

  my $dna1 = shift ;
  my $dna2 = shift ;

  my @in1; my @in2 ;
  my $in1; my $in2 ;

  my $retry_cnt1 = 0; my $retry_cnt2 = 0 ;
  my $retry_lim = 5 ;
  my $sleeptime = 5 ;
  my $passed1 = 0; my $passed2 = 0 ;

  my $fas1 =
    "http://genes.mit.edu/cgi-bin/fas-ess.pl?&sequence="
      . $dna1
        . "&set=FAS-hex2" ;
  my $fas2 =
    "http://genes.mit.edu/cgi-bin/fas-ess.pl?&sequence="
      . $dna2
        . "&set=FAS-hex2" ;

  until ($passed1) {
    $in1 = get($fas1) ;

    unless(defined $in1) {
      $retry_cnt1++ ;
      die("FAS_ESE1 was unable to be revived.") if ($retry_cnt1 == $retry_lim) ;
      my $sleep = $sleeptime * $retry_cnt1 ;
      print "[RiskMarker::get_FASESE] FAS_ESE1 was unavailable on try $retry_cnt1 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again.\n" ;
      sleep($sleep) ;
    } else {
      $passed1++  ;
    }
  }
  @in1 = split(/\n/,$in1) ;

  until ($passed2) {
    $in2 = get($fas2) ;

    unless(defined $in2) {
      $retry_cnt1++ ;
      die("FAS_ESE2 was unable to be revived.") if ($retry_cnt2 == $retry_lim) ;
      my $sleep = $sleeptime*$retry_cnt2 ;
      print "[RiskMarker::get_FASESE] FAS_ESE2 was unavailable on try $retry_cnt2 of $retry_lim.  I'm going to hibernate for $sleep seconds and try again.\n" ;
      sleep($sleep) ;
    } else {
      $passed2++  ;
    }
  }
  @in2 = split(/\n/,$in2) ;

  my $ct1 = 0 ;
  foreach (@in1) {
    if ( $_ =~ m/color="red"/ ) {
      chomp($_) ;
      $_ =~ s/<font color="red">// ;
      $_ =~ s/<\/font>// ;
      if ( substr( $_, 20, 1 ) ne " " ) {
        $ct1++ ;
      }
    }
  }

  my $ct2 = 0 ;
  foreach (@in2) {
    if ( $_ =~ m/color="red"/ ) {
      chomp($_) ;
      $_ =~ s/<font color="red">// ;
      $_ =~ s/<\/font>// ;
      if ( substr( $_, 20, 1 ) ne " " ) {
        $ct1++ ;
      }
    }
  }

  print "[RiskMarker::get_FASESE] FAS-ESE\t\t$ct1 =[]= $ct2\n" if($verbose) ;

  return $ct1, $ct2 ;

} # end get_FASESE


return 1 ;
