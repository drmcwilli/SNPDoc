package UCSC18;

use strict;
use DBI;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = { };
	bless($self, $class);
	return $self;
}

sub load {
	my $self = shift;
	
	my $dbh=DBI->connect("DBI:mysql:database=hg18;host=genome-mysql.cse.ucsc.edu","genomep","password");

	$self->{data} = $dbh;

	my $sth = $dbh->prepare('SELECT txStart,txEnd,name2 FROM refGene WHERE (chrom = ? AND ((txStart < ? AND txStart > ? ) OR (txEnd > ? AND txEnd < ?)))') or die "FAIL\n";

	$self->{handle} = $sth;

}

sub get {
	my $self = shift;
	my $data = shift;
	my $pos 	 = $data->position;
	my $chr 	 = $data->chromosome;
	
	my $dist_u      = 9999999;
	my $dist_d      = 9999999;
	my $gene_name_u = "None within 500 kb";
	my $gene_name_d = "None within 500 kb";
	my $gene_pos;
	my $gene_title;
	my $temp_dist;
	
	my $left = $pos - 500000;
	if ($left < 0){$left = 0;}
	my $right    = $pos + 500000;

	# If unable to find then don't try.
	if ($chr =~ /Multi/ or !$chr or !$pos){
		$data->near_gene_d("");
		$data->near_dist_d("");
		$data->near_gene_link_d("");
				$data->near_gene_u("");
		$data->near_dist_u("");
		$data->near_gene_link_u("");
		return;
	}
	
	# Set up DB and retrieve.
	
	my $dbh = $self->{data};
	my $sth = $self->{handle};
	unless($dbh){
		$self->load;
	}	
	$chr = "chr" . $chr;
	$sth->execute($chr, $right, $pos, $left, $pos) or die "UCSC database failed:\n " . $sth->errstr;

	# Now we have them all.  Find closest.
	while(my @data = $sth->fetchrow_array()){
	
		$gene_title = $data[2];
		$temp_dist = $data[0] - $pos;
		if($temp_dist > 0){ 
			# looking upstream
			if($temp_dist < 500000 and $temp_dist < $dist_u){
				# new match.
				$dist_u = $temp_dist;
				$gene_name_u = $gene_title;
			}
			
		}else{
			# Looking downstream.
			$temp_dist = $pos-$data[1];
			if($temp_dist < 500000 and $temp_dist < $dist_d){
				# new match.
				$dist_d = $temp_dist;
				$gene_name_d = $gene_title;
			}
			
		}
	}
	
	# Now we need to simply return the distances and the genes.
	if ($dist_u == 9999999){
		$data->near_gene_u("");
		$data->near_dist_u(9999999);
		$data->near_gene_link_u("");
	}else{
		$dist_u /= 1000;
		$data->near_gene_u($gene_name_u);
		$data->near_dist_u($dist_u);
		$data->near_gene_link_u("http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=search&term=". $gene_name_u);
	}
	if ($dist_d == 9999999){
		$data->near_gene_d("");
		$data->near_dist_d(9999999);
		$data->near_gene_link_d("");
	}else{
		$dist_d /= 1000;
		$data->near_gene_d($gene_name_d);
		$data->near_dist_d($dist_d);
		$data->near_gene_link_d("http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=search&term=". $gene_name_d);
	}
	
}

return 1;
