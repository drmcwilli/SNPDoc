package CNV;

use strict;
use warnings;

=pod

=head1 CNV

Parse internal list of variations and report whether the current SNP is in one.

List obtained from:  http://projects.tcag.ca/variation/

=head1 Author

Richard T. Guy

=cut

=head1 Methods

=cut

=pod

=head2 new

Constructor

=cut

sub new {
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  my $self = { };
  bless($self, $class);
  return $self;
}

=pod

=head2 load

Load the data structure.

=cut

sub load {
  my $self = shift;
  my $file = shift;
  my $line; my @head;
  my $loc; my $start; my $end; my $type;

  my %map;

  open(IN, $file) or die "Failed to open CNV file.";
  $line = <IN>;                 #pull header.
  while (<IN>) {
    $line = $_;
    @head = split(" ", $line);
    $loc = shift @head;
    $loc =~ s/chr//;
    $start = shift @head;
    $end = shift @head;
    $type = shift @head;
    push( @{ $map{$loc} } , $start , $end , $type  );
  }
  close IN;
  $self->{list} = { %map };
}

=pod

=head2 test

Test whether the feature is within a feature range.

=cut

sub test {
  my $self = shift;
  my $chr = shift;
  my $pos = shift;

  return "" unless ($chr and $pos);

  my %map = %{ $self->list };
  my @list ;
  if (defined $map{$chr}) {
    @list = @{ $map{$chr} } ;
  } else {
    return "" ;
  }

  while (@list) {
    my $pos1 = shift @list;
    if ($pos >= $pos1) {
      my $pos2 = shift @list;
      if ($pos2 >= $pos) {
        return shift @list;
      } else {
        shift @list;
      }
    } else {
      shift @list; shift @list;
    }

  }
  return "";

}

sub list {
  my $self = shift;
  return $self->{list};
}

return 1;
