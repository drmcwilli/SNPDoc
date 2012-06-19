# $Id: Prim_Transcript.pm,v 1.7 2001/06/18 08:27:53 heikki Exp $
#
# bioperl module for Bio::LiveSeq::Prim_Transcript
#
# Cared for by Joseph Insana <insana@ebi.ac.uk> <jinsana@gmx.net>
#
# Copyright Joseph Insana
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::LiveSeq::Prim_Transcript - Prim_Transcript class for LiveSeq

=head1 SYNOPSIS

  # documentation needed

=head1 DESCRIPTION

Class for PRIM_TRANSCRIPT objects. They consist of a beginlabel, an endlabel (both
referring to a LiveSeq DNA object) and a strand.
The strand could be 1 (forward strand, default), -1 (reverse strand).

=head1 AUTHOR - Joseph A.L. Insana

Email:  Insana@ebi.ac.uk, jinsana@gmx.net

Address: 

     EMBL Outstation, European Bioinformatics Institute
     Wellcome Trust Genome Campus, Hinxton
     Cambs. CB10 1SD, United Kingdom 

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::LiveSeq::Prim_Transcript;
$VERSION=1.0;

# Version history:
# Tue Apr  4 18:11:31 BST 2000 v 1.0 created

use strict;
use vars qw($VERSION @ISA);
use Bio::LiveSeq::Range 1.2; # uses Range, inherits from it
@ISA=qw(Bio::LiveSeq::Range);

=head2 new

  Title   : new
  Usage   : $intron1=Bio::LiveSeq::Prim_Transcript->new(-seq => $objref,
							-start => $startlabel,
							-end => $endlabel, 
							-strand => 1
							);

  Function: generates a new Bio::LiveSeq::Prim_Transcript
  Returns : reference to a new object of class Prim_Transcript
  Errorcode -1
  Args    : two labels and an integer

=cut

1;
