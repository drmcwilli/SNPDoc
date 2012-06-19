package LDsearch;

=pod
Linkage Disequilbrium Search
=cut
sub get_LD_information
{
	shift;
	my $snp = shift;
	my $chr = shift;
	my $type = shift;
	my $tol = shift;

	# Open the file.
	my $infile = "/home/rguy/snpdoc/Data/ld_chr".$chr."_JPT.txt";
	open(IN, $infile) or die ("Couldn't open $infile");

	my $line;
	my $return_vals;

	while(<IN>)
	{
		$line = $_;
		if($line =~ m/^$snp/)
		{
			$return_vals = process_line($line, $tol, $type);
			last;
		}
	}


	close (IN);
	return $return_vals;
}

sub process_line
{
	my $line = shift;
	my $tol = shift;
	my $type = shift;
	my $ret_line = "";

	my @vals = split(" ", $line);
	shift @vals;
	while(@vals)
	{
		my $snp = shift @vals;
		my $md = shift @vals;
		my $r2 = shift @vals;
		my $u1 = shift @vals;
		my $u2 = shift @vals;

		if ($type eq "MD"){
			if($md > $tol){ $ret_line = $ret_line . $snp . " " . $md . " "  }
		}elsif ($type eq "r2"){
			if ($r2 > $tol){ $ret_line = $ret_line . $snp . " " . $r2 . " " }
		}else{
			die("Bad type variable: $type");
		}
	}
	return $ret_line;
}

return 1;
