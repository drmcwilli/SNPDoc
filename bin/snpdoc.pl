#!/usr/bin/perl -w
#
# snpdoc

use strict ;
use warnings ;

use Log::Log4perl ;
use Getopt::Long ;
use File::Basename ;
use CGI qw/:standard *table/ ;
use LWP::Simple qw(!head) ;       # Avoid conflict with CGI::head; if we
                                  # need LWP's use LWP::Simple::head($url)
my $VERSION = "3.2.9" ;

use FindBin::Real qw{RealBin} ;   # Used to point snpdoc to its libraries
use lib RealBin() . '/../lib' ;

my $config_file = RealBin() . '/../data/config.txt' ;
my $cnv_file    = RealBin() . '/../data/variations.txt' ;
my $log_params  = RealBin() . '/../data/log.params' ;

my $cpg_file ;  # assigned below

use SNPData;       # Used to hold all information about the snp.
use ChrRegion;     # Used to perform region checks
use RiskMarker;    # Used to calculate risk with fastsnp algorithm
use CPGIslands;    # Used to find CPGIslands
use CNV;           # Used for variations
use UCSC;          # Used for near to gene calculation.
use NCBIAccess;	   # Used to access NCBI.
use DBWrite ;      # Used for database write

my $starttime = localtime time ;
my $timestamp = substr( time, -3, 3 ) ;

Log::Log4perl::init($log_params) ;
my $log = Log::Log4perl->get_logger('main') ;
my $msg = "SNPDoc version $VERSION starting $starttime." ;
$log->info($msg) ;


# If 1, run on snps, if 2, run on regions, if 3, run on positions.
my $run_type = 0 ;

# Read program options; command line overrides config file
my $options = read_config($config_file) ;
process_inputs($options) ;
check_inputs($options) ;

######################################################################################
# Set up the db, ucsc, cpg, cnv helper objects.  Using "has a" relationship.
#######################################################################################

# my $write_to_database = 0 ;  # Not yet an option
# my $snpdb = 0 ;
# my $snpdb = DBWrite->new ;
# $snpdb->load($config_file) ;

my $snpdb ;
if ($options->{db}) {
  $snpdb = DBWrite->new($options->{dbname}, $options->{user}, $options->{pwd}) ;
  $log->info("Using database $options->{dbname}.") ;
}

# Set up helpers that will converse with ucsc and perform cpgisland and cnv tests.
if($options->{ucsc_version} == 19) {
  $cpg_file = RealBin() . '/../data/GenomeWideCpG.txt' ;
} else {
  $cpg_file = RealBin() . '/../data/GenomeWideCpG.hg18.txt' ;
}

my $cpg_test = CPGIslands->new ;
$cpg_test->load($cpg_file) ;

my $cnv_test = CNV->new ;
$cnv_test->load($cnv_file) ;

my $ucsc_test = UCSC->new ;
$ucsc_test->db_version($options->{ucsc_version}) ;

my $ncbi_access = NCBIAccess->new ;
$ncbi_access->verbose_level($options->{verbose}) ;

### Start of testing.

eval {
  my $data = SNPData->new() ;

  my $progfile = "progress$timestamp.txt";

  unless (open( PROG, ">> $progfile" )) {
    $msg = "Could not open $progfile for progress output: $!" ;
    $log->fatal($msg) ;
    die "[snpdoc] $msg\n" ;
  }

  unless (open( IN, $options->{infile})) {
    $msg = "Cannot open input file $options->{infile}: $!" ;
    $log->fatal($msg) ;
    die("[snpdoc] error 3: $msg.\n") ;
  }

  my @input = <IN> ;
  close IN ;

  my $header = shift @input ;

  unless (open OUTPUT, ">", $options->{outfile}) {
    my $msg = "Could not open $options->{outfile} for output: $!" ;
    $log->fatal($msg) ;
    die "[snpdoc] $msg.\n" ;
  }

  chomp $header ;
  my @head_fields = split( /$options->{sep}/o, $header ) ;
  shift @head_fields unless $options->{search} =~ m/reg/ ;  # shift off the snp field label

  #######################################
  ### end of initial  setup.  ###########
  #######################################

  my $marker ;
  my $line ;
  my $total   = 0 ;
  my $linenum = 0 ;

  print "SNPDoc version $VERSION started file $options->{infile}.\n" ;

  my $found = 0 ;
  if (defined $options->{restart}) {
    $msg = "Seeking start SNP $options->{restart}" ;
    $log->info($msg) ;
    print "[snpdoc] $msg.\n" ;
  TEST:
    foreach my $line (@input) {
      $linenum++ ;
      my ($snp, @rest) = split( /$options->{sep}/o, $line ) ;
      if ($snp =~ m/$options->{restart}/xi) {
        $found = 1 ;
        last TEST ;
      }
    }
    unless ($found) {
      $msg = "Could not find start SNP $options->{restart}.  Starting at the top of the list." ;
      $log->info($msg) ;
      print "[snpdoc] $msg.\n" ;
      $linenum = 0 ;
    }
  }  # end if restart

  my $input_end = scalar(@input) - 1 ;
  my @new_input = @input[$linenum .. $input_end] ;

  #################
  ### Main Loop ###
  #################

  if ($run_type == 1) {         # process snp input

    $msg = "Starting snp processing in main" ;
    $log->debug($msg) ;

    if ($options->{outformat} =~ m/(text|txt)/i) {
      write_text_header(\@head_fields) ;
    }
    elsif ($options->{outformat} =~ m/htm/i) {
      write_html_header(\@head_fields) ;
    }

  SNP:
    foreach my $line (@new_input) {
      chomp $line ;
      $data->clear() ;

      $line = trim_line($line) ;
      my ($snp, @user_flds) = split(/$options->{sep}/o, $line) ;

      $linenum++ ;
      if ($snp !~ m/^rs\d+$/) {
        $msg = "Bad SNP name \"$snp\" on line $linenum, skipping." ;
        $log->info($msg) ;
        print "[snpdoc] $msg\n" ;
        unshift(@user_flds, $snp) ;
        write_blank_text(\@user_flds) if $options->{outformat} =~ m/(text|txt)/i ;
        write_blank_html(\@user_flds) if $options->{outformat} =~ m/html/i ;
        next SNP ;
      }

      print "$linenum:\t$snp\n" ;

      if ( ($options->{db}) && ($snpdb->snp_in_db($snp, $options->{ucsc_version})) ) {
        $snpdb->fill_data($data, $snp) ;
        write_text_output($data, \@user_flds) if $options->{outformat} =~ m/(text|txt)/i ;
        write_html_output($data, \@user_flds) if $options->{outformat} =~ m/html/i ;
        next SNP ;
      }

      $data->type("snp") ;
      $data->marker($snp) ;
      $data->version($options->{ucsc_version}) ;

      process_snp($data) ;
      $msg = "Returned to main from process_snp." ;
      $log->debug($msg);

      get_cpg($data) ;

      if ( ($options->{db})                  &&
           ($data->{chrom} =~ m/^[\dXY]+$/i) &&
           ($data->{posit} =~ m/^\d+$/)      &&
           (!$snpdb->snp_in_db($snp, $options->{ucsc_version}))
         ) {
        $snpdb->put($data)  ;
      }

      write_text_output($data, \@user_flds) if $options->{outformat} =~ m/(text|txt)/i ;
      write_html_output($data, \@user_flds) if $options->{outformat} =~ m/html/i ;
      print PROG $data->marker, "\n" ;

    } # end foreach SNP
  } elsif ($run_type == 2) {    # process regional input

    # write_text_header(\@head_fields) ;
    print OUTPUT join($options->{sep}, "snp", "range", @head_fields), "\n" ;

  REGION:
    foreach my $line (@new_input) {
      chomp $line ;
      $line = trim_line($line) ;
      $linenum++ ;

      my ($region, @user_flds) = split(/$options->{sep}/o, $line) ;

      my @snp_list = () ;
      if ($region !~ m/chr[\dXY]+:\d+-\d+/) {
        $msg = "Bad region format: $region on line $linenum; skipping search." ;
        $log->info($msg) ;
        print "[snpdoc] $msg.\n" ;
        unshift(@user_flds, $region) ;
        print OUTPUT join($options->{sep}, "bad_region", $region, @user_flds), "\n" ;
        next REGION ;
      }

      print "$linenum:\t$region\n" ;

      $data->version($options->{ucsc_version}) ;

      my $snp_list = ChrRegion->fetch_region($data, $region) ;
      foreach my $reg_snp (@$snp_list) {
        if (scalar @user_flds > 0) {
          print OUTPUT join($options->{sep}, $reg_snp, $region, @user_flds), "\n" ;
        } else {
          print OUTPUT $reg_snp, $options->{sep}, $region, "\n" ;
        }
      }

      print PROG $region, "\n" ;

    }    # end foreach REGION

  } elsif ($run_type == 3) {    # process positional input
    $msg = "Starting positional search in main." ;
    $log->debug($msg) ;

    if ($options->{outformat} =~ m/(text|txt)/i) {
      write_text_header(\@head_fields) ;
    }
    elsif ($options->{outformat} =~ m/htm/i) {
      write_html_header(\@head_fields) ;
    }

  POSITION:
    foreach my $line (@input) {
      chomp $line ;
      $data->clear() ;

      $line = trim_line($line) ;
      $linenum++ ;

      my ($pos, @user_flds) = split(/$options->{sep}/o, $line) ;

      if ($pos =~ m/^chr([\dXY]+):(\d+)/) {
        my $chr = $1 ;
        my $bp  = $2 ;

        $data->chromosome($chr) ;
        $data->position($bp) ;
        $data->marker($pos) ;
        $data->type("pos") ;
        $data->version($options->{ucsc_version}) ;

        # Check whether the position is in the db with type 'snp'.
        # If so, return that record
        my $snp ;
        if ( ($options->{db}) &&
             ($snp = $snpdb->position_in_db($chr, $bp, $options->{ucsc_version})))  {

          $msg = "Position search found $snp for $pos." ;
          $log->debug($msg) ;

          $snpdb->fill_data($data, $snp) ;
          $data->marker($snp) ;
          $data->type("snp") ;
          write_text_output($data, \@user_flds) if $options->{outformat} =~ m/(text|txt)/i ;
          write_html_output($data, \@user_flds) if $options->{outformat} =~ m/html/i ;

          print PROG $data->marker, "\n" ;
          print "[snpdoc] $linenum:\t$pos\n" ;
          next POSITION ;
        } elsif ($snp = $ucsc_test->is_snp($data)) {
          $data->type("snp") ;
          $data->marker($snp) ;
          process_snp($data) ;
        } else {
          process_position($pos, $data) ;
          get_cpg($data) ;
        } # if-else db

        # Do not write non-named snp to db for now
        if ( ($options->{db})         &&
             ($data->type() eq "snp") &&
             (!$snpdb->snp_in_db($data->marker, $options->{ucsc_version}))
           ) {
          $snpdb->put($data) ;
        }
        write_text_output($data, \@user_flds) if $options->{outformat} =~ m/(text|txt)/i ;
        write_html_output($data, \@user_flds) if $options->{outformat} =~ m/html/i ;

        print PROG $data->marker, "\n" ;
        print "[snpdoc] $linenum:\t$pos\n" ;
      } else {
        $msg = "Bad position \"$pos\" on line $linenum; skipping." ;
        $log->info($msg) ;
        print "[snpdoc] $msg.\n" ;
        unshift(@user_flds, $pos) ;
        write_blank_text(\@user_flds) if $options->{outformat} =~ m/(text|txt)/i ;
        write_blank_html(\@user_flds) if $options->{outformat} =~ m/html/i ;
        next POSITION ;
      } # if-else pos =~


    }  # end foreach POSITION
  }  # end if runtype position

  write_html_footer() if $options->{outformat} =~ m/htm/i ;

  close OUTPUT ;
  close PROG ;

  print "===== Summary =====\n" ;

  my $endtime = localtime time ;
  print "SNPDoc STARTED: $starttime\n" ;
  print "SNPDoc ENDED:   $endtime\n" ;

  $msg = "SNPDoc ended: $endtime." ;
  $log->info($msg) ;

  exit ;

  ###################################################################################################################
  ###################################################################################################################
  ###             ###################################################################################################
  ### Subroutines ###################################################################################################
  ###             ###################################################################################################
  ###################################################################################################################
  ###################################################################################################################


##############################################################################
#
# print_usage
#
# Print the usage information.
#
# Accepts: None
# Returns: Status
#

sub print_usage {
  my $usage = <<USAGE;
usage:
  snpdoc [options] --infile FILE, where option is one or more of:

  --help          print this help message
  --infile        input file (required)
  --search        search type; one of "snp", "reg", "pos" (default "snp")
  --outfile       output file name; if not specified it will be created from
                  the input file name
  --db            use a database to save and retrieve results
  --dbname        name of the database
  --user          database user name
  --pwd           database password
  --sep           field delimiter in the input file; currently tab and comma
                  are recognized (supply with quotes as "\\t" or ",");
                  default comma
  --outformat     type of output; one of "text" or "html" (default "text")
  --stamp         include a random number for use in temporary files
  --verbose       print more information to the console as snpdoc runs
  --ucsc_version  set the ucsc database version; currently 18 and 19 are
                  recognized (default 19)
  --restart       a snp designation; if given, processing will start at this
                  snp in the file

Options may be given as one letter (e.g. '-h') if this uniquely identifies the
choice.

USAGE

  print $usage, "\n" ;
  return 1 ;
} # end print usage

##############################################################################
#
# trim
#
# Trim leading and trailing white space.
#
# Accepts: Scalar with string.
# Returns: Scalar with string.
#

sub trim {
  my $str = shift ;

  $str =~ s/[\r\n]+//g ;
  $str =~ s/^\s+// ;
  $str =~ s/\s+$// ;

  return $str ;

} # end trim

##############################################################################
#
# read_config
#
# Read the configuration file.
#
# Accepts: Scalar with file name.
# Returns: Scalar with reference to hash.

sub read_config {
  my $log = Log::Log4perl->get_logger("read_config") ;
  my $err = "" ;

  my $fh = shift ;

  unless (open IN, "<", $fh) {
    $err = "Could not open configuration file $fh for input." ;
    $log->fatal($err) ;
    die($err . $!) ;
  }

  my $opts ;
 LINE:
  while (my $line = <IN>) {
    chomp $line ;
    $line =~ s/\#.*$// ;
    next LINE if $line =~ m/^\s*$/ ;

    my ($key, $val) = split(/=/, $line) ;
    $key = trim($key) ;
    $val = trim($val) ;

    $opts->{$key} = $val ;
  }

  return $opts ;

} # end read_config



##############################################################################
#
# process_inputs
#
# Process the command line input. Check for validity and update
# option variables.
#
# Accepts: Hash reference with options
# Returns: Status
#

  sub process_inputs {
    my $log = Log::Log4perl->get_logger("process_inputs") ;
    my $err = "" ;
    my $opt = shift ;

    GetOptions($opt,
               'help',
               'db',
               'dbname:s',
               'user:s',
               'pwd:s',
               'infile=s',
               'search=s',
               'outfile:s',
               'sep:s',
               'outformat:s',
               'stamp',
               'verbose',
               'ld',
               'ucsc_version:i',
               'restart:s'
              ) ;

    if ($opt->{help}) {
      print_usage() ;
      $err = "Printing requested help and exiting." ;
      $log->fatal($err) ;
      die($err) ;
    }
    unless ($opt->{infile}) {
      print_usage() ;
      $err = "Exiting, no input file supplied." ;
      $log->fatal($err) ;
      die($err) ;
    }
    return 1 ;
  } # end process_inputs

##############################################################################
#
# check_inputs
#
# Check input validity and adjust state in global variables.
#
# Accepts: Reference to hash of options
# Returns: Status
#

  sub check_inputs {
    my $log = Log::Log4perl->get_logger("check_inputs") ;
    my $err = "" ;
    my $opt = shift ;

    unless ($opt->{infile}) {
      $err = "Exiting, no input file supplied." ;
      $log->fatal($err) ;
      die "[snpdoc] The input file (--infile FILE) is required.\n" ;
    } else {
      $log->info("Taking input from file $opt->{infile}.") ;
    }

    unless ($opt->{outfile}) {
      my($base, $path, $suffix) = fileparse($opt->{infile}, qr/\.[^.]*/) ;
      if ($opt->{outformat} =~ m/(text|txt)/i) {
        $opt->{outfile} = $base . "_out\.txt" ;
      } elsif ($opt->{outformat} =~ m/htm/i) {
        $opt->{outfile} = $base . "_out\.html" ;
      } else {
        $log->info("Unrecognized output file type: $opt->{outformat}. Default to text output.") ;
        print "[snpdoc] Unrecognized output file type: $opt->{outformat}. Default to text output.\n" ;
        $opt->{outformat} = "text" ;
        $opt->{outfile} = $base . "_out\.txt" ;
      }
    }

    $log->info("Output type $opt->{outformat} to file $opt->{outfile}.") ;
    $opt->{sep} = "\t" if $opt->{sep} =~ m/\\t/ ;
    $opt->{sep} = "\t" if $opt->{outformat} =~ m/text|txt/i ;

    if ($opt->{search} =~ m/snp/) {
      $run_type = 1 ;
    } elsif ($opt->{search} =~ m/reg/) {
      $run_type = 2 ;
    } elsif ($opt->{search} =~ m/pos/) {
      $run_type = 3 ;
    } else {
      $log->fatal("Unrecognized search type: $opt->{search}") ;
      die "[snpdoc] Aborting - Unrecognized search type: $opt->{search}.\n" ;
    }

     # Genome db build version
    if ($opt->{ucsc_version}) {
      if ($opt->{ucsc_version} =~ m/(1[89])/) {
        $opt->{ucsc_version} = $1 ;
        $log->info("Using ucsc_version $opt->{ucsc_version}") ;
      } else {
        $log->warn("Did not recognize supplied ucsc_version, using ucsc_version 19.") ;
        $opt->{ucsc_version} = 19 ;
      }
    } else {
      $log->info("Using ucsc_version $opt->{ucsc_version}") ;
      $opt->{ucsc_version} = 19 ;
    }

    return 1 ;

  } # end check_inputs


##############################################################################
#
# trim_line
#
# Trim line feeds, carriage returns and spaces from data lines
#
# Accepts: Scalar with string
# Returns: Scalar with string
#

sub trim_line {
  my $line = shift ;

  $line =~ s/[\r\n]+//g ;
  $line =~ s/^\s+// ;
  $line =~ s/\s+$// ;

  return $line ;
} # end trim_line

##############################################################################
#
# process_position
#
# Fill data assuming positional input.
#
# Accepts: Scalars with marker and reference to data
# Returns: Status

  sub process_position {
    my $log = Log::Log4perl->get_logger("process_position") ;
    my $msg = "In process_position." ;
    $log->debug($msg) ;

    my $marker = shift ;
    my $data   = shift ;

    $ucsc_test->get_from_position($data) ;

    if ($log->is_debug()) {
      $msg = "After ucsc->get_from_position.\n" . $data->_return_data  ;
      $log->debug($msg) ;
    }

    $ucsc_test->get_conservation($data) ;

    # Either get gene and do risk or calc nearest and create output.
    if ( $data->gene ) {
      process_gene($data->gene) ;
    } else {          # This SNP is not in a gene.  Check for nearest.
      $ucsc_test->get_nearest($data)  ;
    }

    # Current risk calculation assumes named snp
    $data->risk("NA")  ;
    $data->classification("NA")  ;

    $data->version($options->{ucsc_version}) ;
    $data->merged_here("NA") ;
    $data->URL("NA") ;
    my $pos  = $data->position ;
    my $pos1 = $pos - 1000 ;
    my $pos2 = $pos + 1000 ;
    my $chr  = $data->chromosome ;
    $data->UCSC_URL("http://www.genome.ucsc.edu/cgi-bin/hgTracks?&clade="
                    . "mammal&org=Human&db=hg19&position=chr"
                    . $chr . ":" . $pos1 . "-" . $pos2 ) ;

    $msg = "Leaving process_position." ;
    $log->debug($msg) ;

    return 1 ;
  } # end process_position


##############################################################################
#
# process_snp
#
# Fill data assuming SNP input.
#
# Accepts: Reference to data structure
# Returns: Status
#

  sub process_snp {
    my $log = Log::Log4perl->get_logger("process_snp") ;
    my $msg = "" ;
    my $data = shift  ;

    $msg = "In process_snp." ;
    $log->debug($msg) ;

    my $marker = $data->marker ;
    # New in version 3.0 (Sept, 2010) RTG
    $ucsc_test->get_snpinfo($data);         # Sets data->chr, pos, gene, description
    $ncbi_access->get_sequence_data($data); # Sets data->all1, all2, dna1, dna2

    $msg = "After first UCSC and NCBI access." ;
    $log->debug($msg) ;

    my $notes = join("; ", (keys %{$data->note})) ;
#    if ($data->chromosome =~ m/not found/) {
    if ($notes =~ m/not found/i) {
      $ncbi_access->get_merged($data) ;     # Ascertain whether the snp was merged into an new name; updates data->marker, if so.
      $ucsc_test->get_snpinfo($data) ;      # Try again with the new marker name.
    }

    if ($log->is_debug()) {
      $msg = "After retry \"if data->chromosome not found, ncbi->get_merged, ucsc->get_snpinfo\". \n" . $data->_return_data  ;
      $log->debug($msg) ;
    }

#    if ( $data->chromosome =~ m/not found/ ) {
    # if ( $notes =~ m/not found/i ) {
    #   $data->chromosome("NA") ;
    #   $data->risk("NA")  ;
    #   $data->classification("NA")  ;
    # }

    if ( $data->position ) {
      $data->URL( "http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?rs=" . $data->marker )  ;
      $data->UCSC_URL("http://www.genome.ucsc.edu/cgi-bin/hgTracks?&clade=mammal&org=Human&db=hg19&position=" . $data->marker )  ;
      $data->Chr_URL("http://www.ncbi.nlm.nih.gov/mapview/map_search.cgi?taxid=9606&query=" . $data->marker)  ;
      $ucsc_test->get_conservation($data) ;
    }

    if ($log->is_debug) {
      $msg = "After \"if data->position()\", should have set URLs and retrieved conservation.\n )" . $data->_return_data ;
      $log->debug($msg) ;
    }

    # Either get gene and do risk or calc nearest and create output.
    if ( ($data->gene)        ||
         ($data->near_gene_u) ||
         ($data->near_gene_d) ) {
      process_gene($data->gene) ;
      # RiskMarker->calc_risk( $options->{verbose}, $data ) ;
      RiskMarker->calc_risk_ucsc($data) ;
    } else {          # This SNP is not in a gene.  Check for nearest.
      $ucsc_test->get_nearest($data)  ;
      $data->risk("NA")  ;
      $data->classification("NA")  ;
    }

    if ($log->is_debug) {
      $msg = "After \"if data->gene()\" (do risk or calc nearest).\n" . $data->_return_data ;
      $log->debug($msg) ;
    }

    return 1 ;

  } # End process_snp.

##############################################################################
#
# process_gene
#
# Clean up gene and gene description, score with the risk calculation.
#
# Accepts: Reference to list of genes
# Returns: Status
#

  sub process_gene {
    my $log = Log::Log4perl->get_logger("process_gene") ;
    my $msg = "In process_gene" ;
    $log->debug($msg) ;

    my $genes = shift  ;

    # Load aliases.
    for my $g (split(/,/, $genes) ) {
      $ncbi_access->get_gene_alias($g, $data)  ;
    }

    my $one_gene = $genes  ;
    $one_gene =~ s/,*//; # Delete everything after first ','.
    $data->gene_URL("http://www.genome.ucsc.edu/cgi-bin/hgTracks?&clade=mammal&org=Human&db=hg19&position=$one_gene")  ;

    # clean up our output.
    my $tmp = $data->alias  ;
    $tmp =~ s/^[;\s]+//  ;
    $tmp =~ s/[;\s]+$//  ;
    $tmp =~ s/,/;/g ; # Substitute semi-colon for comma in case csv output
    $data->alias($tmp)  ;

    $tmp = $data->description  ;
    $tmp =~ s/;\s$//  ;
    $tmp =~ s/^[;\s]//  ;
    $data->description($tmp)  ;

    if ($options->{verbose}) {
      print "Gene information: " . $data->description . " -- " . $data->alias . "\n"  ;
    }

    return 1 ;
  } # end process_gene

##############################################################################
#
# get_cpg
#
# Get CPG island stuff, etc.
#
# Accepts: Reference to data structure
# Returns: Status
#

sub get_cpg {

  my $local_data = shift  ;
  # Calculate CpG island status and build ucsc URL.
  if ( $local_data->position =~ m/\d/ and $local_data->chromosome =~ m/[\dXY]/ ) {
    my $t1 = $cpg_test->test( $local_data->chromosome, $local_data->position )  ;

    # Get whether affects.
    if ( $cpg_test->affects_CG($local_data) ) {
      $t1 .= ' *'  ;
      print $local_data->dna1 . "  " . $local_data->dna2 . "\n" if ($options->{verbose})  ;
    }
    print "CpG Island Value: " . $t1 . "\n" if ( $options->{verbose} and $t1 )  ;
    $local_data->CpG($t1)  ;

    my $t2 = $cnv_test->test( $local_data->chromosome, $local_data->position )  ;
    print "Variation Value: " . $t2 . "\n" if ( $options->{verbose} and $t2 )  ;
    $local_data->CNV($t2)  ;
  }

  return 1  ;

} # end get_cpg

###################################################################################################################
###################################################################################################################
##############################  OUTPUT PROCEDURES  ################################################################
###################################################################################################################
###################################################################################################################

##############################################################################
#
# write_text_header
#
# Write the header line to the text output file.  Assumes already opened
# filehandle 'OUTPUT'
#
# Accepts: Reference to array
# Returns: Status

sub write_text_header {
  my $user_fields = shift ;

  my @text_fields = qw(Marker NCBI UCSC Chr Position Nearest_Upstream
                       Nearest_Upstream_URL Nearest_Downstream
                       Nearest_Downstream_URL InGene Description
                       GeneURL Alias Conservation Risk SNP_Function
                       CpG_Region Variation_Region Build SNP_Aliases
                       note)
                       ;

  push @text_fields, @{$user_fields} ;

  print OUTPUT join($options->{sep}, @text_fields), "\n" ;

  return 1 ;
}  # end write_text_header

##############################################################################
#
# write_html_header
#
# Write the html page header, table start, and header row.  Assumes
# already open filehandle 'OUTPUT'.
#
# Accepts: Reference to array
# Returns: Status
#

sub write_html_header {
  my $user_fields = shift ;

my $table_style = <<END;
body
{
	line-height: 1.6em;
}

#minimalist
{
        table-layout: auto ;
	font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
	font-size: 12px;
	background: #fff;
	margin: 45px;
/*	width: 100%; */
	border-collapse: collapse;
	text-align: left;
	border-top: 2px solid #6678b1;
 	border-bottom: 2px solid #6678b1;
}
#minimalist th
{
	font-size: 14px;
	font-weight: normal;
	color: #039;
	padding: 10px 8px;
        border-bottom: 1px solid #6678b1;
        border-left:   1px solid #6678b1;
        border-right:  1px solid #6678b1; 

}
#minimalist td
{
	border-bottom: 1px solid #ccc;
        border-left:   1px solid #ccc ;
        border-right:  1px solid #ccc ;
	color: #669;
	padding: 6px 8px;
}
#minimalist tfoot
{

}

#minimalist tbody tr:hover td
{
	color: #009;
}

.minimalist-text-col
{
        min-width: 225px;
}

END

  print OUTPUT header('') ;
  print OUTPUT start_html({-title => 'SNPDoc Report',
                           -style => {-code => $table_style}}
                         ) ;

  my @html_fields = qw(Marker NCBI UCSC Chr Position Nearest_Upstream
                       Nearest_Downstream In_Gene Description Alias
                       Conservation Risk SNP_Function CpG_Region
                       Variation_Region Build SNP_Aliases note) ;

  push @html_fields, @{$user_fields} ;

  print OUTPUT start_table({-id => "minimalist"}) ;
  print OUTPUT thead(Tr(th(\@html_fields))) ;
  print OUTPUT "\n" ;

  my $col_fmts =  <<COLS;
    <colgroup>
    	<col/>
    	<col/>
        <col/>
    	<col/>
    	<col/>
    	<col class="minimalist-text-col"/>
        <col class="minimalist-text-col" />
    	<col/>
    	<col class="minimalist-text-col" />
    	<col/>
        <col/>
    	<col/>
    	<col class="minimalist-text-col"/>
    	<col/>
        <col/>
    	<col/>
    	<col class="minimalist-text-col" />
        <colclass="minimalist-text-col" />
        <col/>
    </colgroup>

COLS

  print OUTPUT $col_fmts ;
  print OUTPUT "\n" ;

  return 1 ;

} # end write_html_header

##############################################################################
#
# write_blank_text
#
# Called if there is a mal-formed snp designation.  Write output with
# empty fields.  Assumes an already open filehandle 'OUTPUT'.
#
# Accepts: Scalar with reference to array
# Returns: Status
#

sub write_blank_text {
  my $flds = shift ;
  my @fields = @{$flds} ;
  my $marker = shift @fields ;
  my $sep = $options->{sep} ;

  print OUTPUT $marker, $sep ;

  # There are 21 fields for the text output
  for (my $i=0; $i<20; $i++) {
    print OUTPUT $sep ;
  }

  if (scalar @fields > 0) {
    print OUTPUT join($sep, @fields) ;
  }

  print OUTPUT "\n" ;

  return 1 ;
} # end write_blank_text

##############################################################################
#
# write_blank_html
#
# Called if there is a mal-formed snp designation.  Write html table row
# output with empty fields.  Assumes an already open filehandle 'OUTPUT'.
#
# Accepts: Reference to array
# Returns: Status
#

sub write_blank_html {
  my $flds = shift ;
  my @fields = @{$flds} ;
  my $marker = shift @fields ;

  print OUTPUT "<tr>\n" ;
  print OUTPUT td($marker) ;

  # There are 18 fields for the html output
  for (my $i=0; $i<17; $i++) {
    print OUTPUT td() ;
  }

  if (scalar @fields > 0) {
    print OUTPUT td(\@fields) ;
  }

  print OUTPUT "</tr>\n" ;

  return 1 ;
} # end write_blank_html

##############################################################################
#
#  write_text_output
#
# Write a data line as tab-delimited text. Assumes already opened
# filehandle 'OUTPUT'.
#
# Accepts: References to data structure and array
# Returns: Status
#

sub write_text_output {
  my $data = shift ;
  my $user_fields = shift ;
  my $sep = $options->{sep} ;

  print OUTPUT join($sep, $data->marker_text, $data->URL,
                 $data->UCSC_URL, $data->chromosome, $data->position,
                 $data->near_gene_text_u, $data->near_gene_link_u,
                 $data->near_gene_text_d, $data->near_gene_link_d,
                 $data->gene, $data->description, $data->gene_URL,
                 $data->alias, $data->cons_multiz, $data->risk_ucsc,
                 $data->classification_ucsc, $data->CpG, $data->CNV,
                 $data->version, $data->merged_here, $data->note) ;

  print OUTPUT $sep ;
  print OUTPUT join($sep, @{$user_fields}) ;

  print OUTPUT "\n" ;

  return 1 ;
} # end write_text_output

##############################################################################
#
# write_html_output
#
# Write a data line as an html table row.  Assumes an already opened
# filehandle 'OUTPUT'.
#
# Accepts: References to data structure and array
# Returns: Status
#

sub write_html_output {
  my $data = shift ;
  my $user_fields = shift ;

  print OUTPUT "<tr style=\"data_row\">\n" ;

  my $anchor_name ;
  my $marker_fmt ;
  # print OUTPUT td($data->marker_text), "\n" ;
  if ( (defined $data->note) &&
       ((scalar keys %{$data->note})>0)) {
    $anchor_name = $data->marker . "_note" ;
    $marker_fmt = join("",
                       qq(<a href="#$anchor_name">),
                       $data->marker,
                       qq(</a>)) ;
  } else {
    $marker_fmt = $data->marker
  }
  print OUTPUT td($marker_fmt), "\n" ;

  if ( ( $data->URL ) and $data->URL !~ m/N.A/ ) {
    print OUTPUT td( a({href=>$data->URL}, "NCBI") ), "\n" ;
  } else {
    print OUTPUT td("&nbsp;"), "\n" ;
  }

  if ( $data->UCSC_URL and $data->UCSC_URL !~ m/N.A/ ) {
    print OUTPUT td( a({href=>$data->UCSC_URL}, "UCSC") ), "\n" ;
  } else {
    print OUTPUT td("&nbsp;"), "\n" ;
  }

  if ( $data->Chr_URL ) {
    print OUTPUT td( a({href=>$data->Chr_URL}, $data->chromosome) ), "\n" ;
  } else {
    print OUTPUT td($data->chromosome), "\n" ;
  }

  print OUTPUT td($data->position), "\n" ;

  # If we are in a gene, then print two blanks.  Otherwise print URLS
  # for nearest upstream and downstream.
  if ( $data->gene ) {
      print OUTPUT td(), "\n" ; print OUTPUT td(), "\n" ;
  } else {
    if ( $data->near_gene_link_u ) {
      print OUTPUT td( a({href=>$data->near_gene_link_u}, $data->near_gene_text_u) ), "\n" ;
       } else {
      print OUTPUT td($data->near_gene_text_u), "\n" ;
    }
    if ( $data->near_gene_link_d ) {
      print OUTPUT td( a({href=>$data->near_gene_link_d}, $data->near_gene_text_d) ), "\n" ;
    } else {
      print OUTPUT td($data->near_gene_text_d), "\n" ;
    }
  }

  # Now put blanks if not in a gene, otherwise url, alias, descr
  if ( $data->gene ) {
    print OUTPUT "<TD>" ;
    my $gene_urls = $data->gene_URL ;
    my $gene      = $data->gene ;
    my @genes     = split( /;/, $gene ) ;
    my @links     = split( /;/, $gene_urls ) ;
    while (@genes) {
      $gene_urls = shift @links ;
      $gene      = shift @genes ;
      print OUTPUT "<a href=\"" . $gene_urls . "\">" . $gene . "</a>" ;
    }

    print OUTPUT "</TD>\n" ;

    print OUTPUT td($data->description), "\n" ;
    print OUTPUT td($data->alias), "\n" ;
  } else {
    print OUTPUT td(), "\n" ; print OUTPUT td(), "\n" ; print OUTPUT td(), "\n" ;
  }

  # On to risk, ect.
  print OUTPUT td($data->cons_multiz), "\n" ;

  # [drm] FIXME remove duplicates after testing
  #  print OUTPUT td($data->risk), "\n" ;
  print OUTPUT td($data->risk_ucsc), "\n" ;

  # print OUTPUT td($data->classification), "\n" ;
  print OUTPUT td($data->classification_ucsc), "\n" ;

  print OUTPUT td($data->CpG), "\n" ;
  print OUTPUT td($data->CNV), "\n" ;
  print OUTPUT td($data->version), "\n" ;
  print OUTPUT td($data->merged_here), "\n" ;

  my $note_fmt ;
  if ((defined $data->note) &&
      ((scalar keys %{$data->note})>0)) {
    my $h_note = $data->note ;
    my @notes ;
    foreach my $k (keys %{$h_note}) {
      push @notes, $k ;
    }
    my $note_text = join("; ", @notes) ;
    $note_fmt = $note_text . qq(<a name="$anchor_name"></a>) ;
  } else {
    $note_fmt = " " ;
  }

  print OUTPUT td($note_fmt), "\n" ;

  # If there is anything left in the user_fields, print it
  while ( @{$user_fields} ) {
    my $temp1 = shift @{$user_fields} ;
    print OUTPUT td($temp1), "\n" ;
  }

  print OUTPUT "</tr>\n\n" ;

  return 1 ;
} # end write_html_output

##############################################################################
#
# write_html_footer
#
# Write the html_foot material.  Assumes an already open filehandle
# 'OUTPUT'.
#
# Accepts: None
# Return: Status
#

sub write_html_footer {
  print OUTPUT end_table() ;
  print OUTPUT end_html() ;
  return 1 ;
} # end write_html_footer

##############################################################################
#                                                                            #
#                           End Functions                                    #
#                                                                            #
##############################################################################

} ;  # end eval() main processing block

if ($@) {
  $log->fatal("SNPdoc has encountered an error and will terminate.") ;
    print "[snpdoc] SNPdoc has encountered an error and will terminate.\n $@" ;

    if ( $@ =~ m/^error\s(\d)/ ) {
        exit($1) ;
    }
}

# end snpdoc

__END__

=head1 NAME

  snpdoc.pl

=head1 SYNOPSIS

  Aggregate genetic information about a list of SNPs, genomic regions,
  or positions and combine it with user defined information such as
  statistical results.

=head1 USAGE

usage:
  snpdoc [options] -infile FILE, where option is one or more of:

  --help          print this help message
  --infile        input file (required)
  --search        search type; one of "snp", "reg", "pos" (default "snp")
  --outfile       output file name; if not specified it will be created from
                  the input file name.
  --db            use a database to save and retrieve results
  --dbname        name of the database
  --user          database user name
  --pwd           database password
  --sep           input record separator
  --outformat     type of output; one of "text" or "html" (default "text")
  --stamp         include a random number for use in temporary files
  --verbose       print more information to the console as snpdoc runs
  --ucsc_version  set the ucsc database version; currently 18 and 19 are
                  recognized (default 19)
  --restart       a snp designation; if given, processing will start after
                  this snp in the file

=head1 Methods

=head2 print_usage

 Print the usage information.

 Accepts: None
 Returns: Status

=head2 trim

  Trim leading and trailing white space.

  Accepts: Scalar with string.
  Returns: Scalar with string.

=head2 read_config

  Read the configuration file.

  Accepts: Scalar with file name.
  Returns: Scalar with reference to hash.

=head2 process_inputs

 Process the command line input. Check for validity and update
 option variables.

 Accepts: Hash reference with options
 Returns: Status

=head2 check_inputs

 Check input validity and adjust state in global variables.

 Accepts: Reference to hash of options
 Returns: Status

=head2 trim_line

 Trim line feeds, carriage returns and spaces from data lines

 Accepts: Scalar with string
 Returns: Scalar with string

=head2 process_position

 Fill data assuming positional input.

 Accepts: Scalars with marker and reference to data
 Returns: Status

=head2 process_snp

 Fill data assuming SNP input.

 Accepts: Reference to data structure
 Returns: Status

=head2  process_gene

 Clean up gene and gene description, score with the risk calculation.

 Accepts: Reference to list of genes
 Returns: Status


=head2 get_cpg

 Get CPG island stuff, etc.

 Accepts: Reference to data structure
 Returns: Status

=head2 write_text_header

 Write the header line to the text output file.  Assumes already
 opened filehandle 'OUTPUT'.

 Accepts: Reference to array
 Returns: Status

=head2 write_html_header

 Write the html page header, table start, and header row.  Assumes
 already open filehandle 'OUTPUT'.

 Accepts: Reference to array
 Returns: Status

=head2 write_blank_text

 Called if there is a mal-formed snp designation.  Write output with
 empty fields.  Assumes an already open filehandle 'OUTPUT'.

 Accepts: Scalar with reference to array
 Returns: Status

=head2  write_blank_html

 Called if there is a mal-formed snp designation.  Write html table row
 output with empty fields.  Assumes an already open filehandle 'OUTPUT'.

 Accepts: Reference to array
 Returns: Status

=head2 write_text_output

 Write a data line as tab-delimited text. Assumes already opened
 filehandle 'OUTPUT'.

 Accepts: References to data structure and array
 Returns: Status

=head2 write_html_output

 Write a data line as an html table row.  Assumes an already opened
 filehandle 'OUTPUT'.

 Accepts: References to data structure and array
 Returns: Status

=head2 write_html_footer

 Write the html_foot material.  Assumes an already open filehandle
'OUTPUT'.

 Accepts: None
 Return: Status

=head1 AUTHOR

  Richard T. Guy
  Department of Mathematics
  Department of Computer Science
  Department of Biostatistical Sciences
  Wake Forest University
  (Current affiliation: Dept. of Computer Science, University of Toronto)

  David R. McWilliams
  Department of Biostatistical Sciences
  Wake Forest University School of Public Health

  First version by Wei Wang


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006-2012 by Wake Forest University This program is free
software; you can redistribute it and/or modify it under the same
terms as Perl itself.  The full license can be found at
http://dev.perl.org/licenses/

In particular (taken from GNU), the copyright holders and the author
provide the program "as is" without warraynty of any kind, either
expressed or implied, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose.
The entire risk as to the quality and performance of the program is
with you.  Should the program prove defective, you assume the cost of
all necessary servicing, repair, or correction.

=head1 Error flags

  The following scheme is required for all error messages.
	  Use flag "error 1" for connection related problems.
	  Use flag "error 2" for WFU database related problems.
	  Use flag "error 3" for all others.

=cut
