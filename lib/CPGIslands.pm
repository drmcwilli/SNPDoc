package CPGIslands ;
use Log::Log4perl ;

=head1 CPGIslands

  Use the stored CPG island list to identify CPG islands.

  List from http://genome.ucsc.edu/cgi-bin/hgTables?

=head1 Author

  Richard T. Guy

=head1 TODO

=over

=item * Could use the UCSC tables to do this.

=item * Declare variable $sm in CPGIslands->test, c. line 94

=back


=head1 Methods

=head2 new

  Constructor

=cut

sub new {
  my $log = Log::Log4perl->get_logger("new") ;
  my $msg = "In constructor." ;
  $log->debug($msg) ;

  my $invocant = shift ;
  my $class = ref($invocant) || $invocant ;
  my $self = {  } ;
  bless($self, $class) ;
  return $self ;
}

=head2 load

  Load hash with CpG data.

=cut

sub load {
  my $log = Log::Log4perl->get_logger("load") ;
  my $msg = "In load." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $file = shift ;

  my $line ; my @head ;
  my $loc ;  my $start ; my $end ;

  my %map ;

  open (IN, $file)
    or die "Failed to open CpG file." ;

  $line = <IN> ;
  while (<IN>) {
    $line = $_ ;
    @head = split(" ", $line) ;
    $loc = shift @head ;
    if ($loc =~ m/([\dXY]+)/) {
      $loc = $1 ;
      $start = shift @head ;
      $end   = shift @head ;
      push( @{$map{$loc} } , $start , $end ) ;
    }
  }
  close IN ;
  $self->{list} = { %map } ;
}  # CPGIslands->load()


=head2 test

  We have an array (@list) that contains start and stop positions.  Go
  through the list until we are in between two elements.  Count number
  of elements seen.  If we are in between even-odd then we are in an
  island.  If not, return distance to one of the two that we are
  between.

=cut

sub test {
  my $log = Log::Log4perl->get_logger("test") ;
  my $msg = "In test." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $chr  = shift ;
  my $pos  = shift ;
  return 0 unless ($chr and $pos) ;

  # print "CPGIslands::test Called with chr, pos: |", $chr, "|", $pos, "|\n" ;

  my %map = %{ $self->list } ;
  my @list ;
  if (defined $map{$chr}) {
    @list = @{$map{$chr}} ;
  } else {
    return 0 ;
  }

  # Check that we aren't smaller than all of them.  We have to find
  # smallest.  $self->{small} is set in the function small() below

  if ($self->{small}->{$chr}) {
    $sm = $self->{small}->{$chr} ;
    return $sm-$pos if ($sm > $pos) ;
  }
  my $sm = 10000000 ;
  foreach my $num (@list) {
    $sm = $num if($num < $sm) ;
  }
  if ($sm > $pos) {
    return $sm-$pos ;
  }

  my $cnt = 0 ;
  my $pos1 ;
  while (@list) {
    $pos1 = shift @list ;
    if ($pos >= $pos1) {
      # Return value here.
      if ($pos < $list[0]) {	  # We are in between two positions.
        my $pos2 = shift @list ;
        if ($cnt % 2 == 0) {
          # In a cpg
          return -1 ;
        } else {
          return ($pos-$pos1 < $pos2-$pos) ? ($pos-$pos1) : ($pos2-$pos)  ;
        }
      }
    }
    $cnt++ ;
  }

  # pos1 contains last end point.
  return $pos - $pos1  ;

} # CPGIslands->test()

=head2 affects_CG

  Test whether the SNP actually affects a C followed by G or G
  following C.  Note: dna1 and dna2 return entire string.  We must
  compare the two and find the place where they differ.  That is the
  SNP.  From there, can use one forward or one back.

=cut

sub affects_CG {
  my $log = Log::Log4perl->get_logger("affects_CG") ;
  my $msg = "affects_CG" ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;

  my $all1 = $data->allele1 ;
  my $all2 = $data->allele2 ;

  my $d1 = $data->dna1 ;
  my $d2 = $data->dna2 ;
  my @da = split(//, $d1);       # Split on anything.
  my @db = split(//, $d2);       # Same.

  my $i = 0 ;

  if ($d1 eq "" or $d2 eq "") {
    return 0 ;
  }

  while ($da[$i] eq $db[$i] and $i < scalar @da) {
    $i++ ;
  }

  if ($all1 eq "C" or $all2 eq "C") {
    # Check for CG, so second spot is G.
    return 1 if($da[$i+1] eq "G") ;
  }
  if ($all1 eq "G" or $all2 eq "G") {
    return 1 if($da[$i+1] eq "C") ;
  }
  return 0 ;
} # CPGIslands->affects_CG


=head2 list

  Simply return the list of all CpG islands.

=cut

sub list {
  my $log = Log::Log4perl->get_logger("list") ;
  my $msg = "In list." ;
  $log->debug($msg) ;

  my $self = shift ;
  return $self->{list} ;
}

=head2 small

  Set the small slot.

=cut

sub small {
  my $log = Log::Log4perl->get_logger("small") ;
  my $msg = "In small." ;
  $log->debug($msg) ;

  my $self  = shift ;
  my $chr   = shift ;
  my $small = shift ;

  $self->{small}->{$chr} = $small ;
}


return 1 ;
