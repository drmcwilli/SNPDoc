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

my $need_pkgs = 0 ;
print "Searching for required perl packages:\n";

print "LWP::Simple installed? ";
if( eval "use LWP::Simple; 1" ) {
  print "Yes!\n"
} else {
  print "No.\n" ;
  $need_pkgs++ ;
}

print "DBI installed? ";
if( eval "use DBI; 1" ) {
  print "Yes!\n";
} else {
  print "No.\n" ;
  $need_pkgs++ ;
}

print "DBD::mysql installed? ";
if( eval "use DBD::mysql; 1" ) {
  print "Yes!\n";
} else {
  print "No.\n";
  $need_pkgs++ ;
  print "For rpm systems (redhat), log in as root and type\n";
  print "rpm -i mysql mysql-devel mysql-server\n";
  print "rpm -i perl-DBI\n";
  print "rpm -i DBD-MySQL\n\n\n";
  print "For Debian systems (Ubuntu), type\n";
  print "sudo apt-get install mysql-server\n";
  print "sudo apt-get install mysql-client mysql-common libdbi-perl libdbd-mysql-perl\n\n";

  print "See manual for install instructions.\n"
}

print "DBD::SQLite installed? " ;
if( eval "use DBD::SQLite; 1" ) {
  print "Yes!\n";
} else {
  print "No.\n" ;
  $need_pkgs++ ;
}

print "FindBin::Real installed? ";
if( eval "use FindBin::Real; 1" ) {
  print "Yes!\n";
} else {
  print "No.\n" ;
  need_pkgs++ ;
}

print "Log::Log4perl installed? " ;
if (eval "use Log::Log4perl; 1") {
  print "Yes!\n" ;
} else {
  print "No.\n" ;
  $need_pkgs++ ;
}

if ($need_pkgs) {
  print "One or more required packages are not present.  Install with CPAN or\nyour package manager.\n" ;
}

# end installScript



