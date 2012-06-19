#!/usr/local/bin/perl

=pod

Simple installer for snpdoc.  See user manual for more information.

Set up file structure and insert information.
Make a symbolic link in $site/bin.

=cut

$site = "/usr/local" ;
$executablesite = "/usr/local/bin" ;

mkdir("$site/snpdoc") or
  die("Could not make directory $site.  Do you have permission?\n");

mkdir("$site/snpdoc/bin");
mkdir("$site/snpdoc/lib");
mkdir("$site/snpdoc/data");

system("cp -v bin/* $site/snpdoc/bin");
system("cp -rv lib/* $site/snpdoc/lib");
system("cp -v data/* $site/snpdoc/data");

# Make the symbolic link
system("ln -s $site/snpdoc/bin/snpdoc.pl $executablesite/snpdoc");
system("chmod 755 $executablesite/snpdoc");
system("chmod -R 755 $site/*");

=pod

For this simple release, all testing occurs right here.

=cut

print "Testing:\n";

print "LWP::Simple installed? ";
if( eval "use LWP::Simple; 1" ) {
  print "Yes!\n"
} else {
  print "No.  See manual for CPAN instructions.\n"
}

print "DBI installed? ";
if( eval "use DBI; 1" ) {
  print "Yes!\n";
} else {
  print "No.  See manual for CPAN instructions.\n"
}

print "DBD::mysql installed? ";
if( eval "use DBD::mysql; 1" ) {
	print "Yes!\n";
} else {
  print "No.\n";
  print "For rpm systems (redhat), log in as root and type\n";
  print "rpm -i mysql mysql-devel mysql-server\n";
  print "rpm -i perl-DBI\n";
  print "rpm -i DBD-MySQL\n\n\n";
  print "For Debian systems (Ubuntu), type\n";
  print "sudo apt-get install mysql-server\n";
  print "sudo apt-get install mysql-client mysql-common libdbi-perl libdbd-mysql-perl\n\n";

  print "See manual for install instructions.\n"
}

print "FindBin::Real installed? ";
if( eval "use FindBin::Real; 1" ) {
  print "Yes!\n";
} else {
  print "No.  See manual for CPAN instructions.\n"
}

# end installScript



