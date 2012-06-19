#!perl

=pod

Simple installer for snpdoc.  See user manual for more information.

Set up file structure and insert information.

=cut
my $site = "C:\\Program Files";
my $executablesite = "C:\\Program Files\\Snpdoc\\bin";

mkdir("$site\\snpdoc") or die("Could not make directory $site.  Do you have permission?\n");
mkdir("$site\\snpdoc\\bin");
mkdir("$site\\snpdoc\\lib");
mkdir("$site\\snpdoc\\data");

system(qq{xcopy bin\\* "$site\\snpdoc\\bin"});
system(qq{xcopy lib\\* "$site\\snpdoc\\lib" /s});
system(qq{xcopy data\\* "$site\\snpdoc\\data"});

system(qq{pl2bat "$site\\snpdoc\\bin\\snpdoc.pl" });
system(qq{set path="$site\\snpdoc\\bin";\%path\%});

=pod
For this simple release, all testing occurs right here.
=cut

open(OUT, ">test_results.txt");

print OUT "Testing:\n";
print OUT "LWP::Simple installed? ";
if( eval "use LWP::Simple; 1" ){
	print OUT "Yes!\n"
}else{print OUT "No.  See manual for CPAN instructions.\n"}
print OUT "DBI installed? ";
if( eval "use DBI; 1" ){
	print OUT "Yes!\n";
}else{print OUT "No.  See manual for CPAN instructions.\n"}
print OUT "DBD::mysql installed? ";
if( eval "use DBD::mysql; 1" ){
	print OUT "Yes!\n";
}else{
	print OUT "No.\n";
	print OUT "See manual for install instructions.\n"
}
print OUT "FindBin::Real installed? ";
if( eval "use FindBin::Real; 1" ){
	print OUT "Yes!\n";
}else{print OUT "No.  See manual for CPAN instructions.\n"}


close(OUT);
