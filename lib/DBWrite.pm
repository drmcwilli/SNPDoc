package DBWrite ;
use POSIX qw(strftime) ;

=head1 DBWrite

  Methods for connecting to and updating the database.

=cut

use strict ;
use DBI ;
use Log::Log4perl ;

my $VERSION = "0.1.3" ;

my $log = Log::Log4perl->get_logger("DBWrite") ;

=head1 Methods

=cut

# sub new{
#   my $invocant = shift ;
#   my $class = ref($invocant) || $invocant ;
#   my $self = {  } ;

#   bless($self, $class) ;
#   $self->{dbname} = "" ;
#   $self->{pwd} = "" ;
#   $self->{username} = "" ;
#   return $self ;
# }

=head2 new

 Constructor

 Accepts: Scalars with database name and optional user and password.
 Returns:

=cut

sub new {
  my $log = Log::Log4perl->get_logger("new") ;
  my $msg = "" ;

  $msg = "In constructor." ;
  $log->debug($msg) ;

  my $invocant = shift ;
  my $class = ref($invocant) || $invocant ;
  my $self = {  } ;

  my @args = @_ ;

  unless (scalar @args > 1) {
    $msg = "DB constructor called with insfufficient arguments." ;
    $log->fatal($msg) ;
    die $msg, "\n" ;
  }

  $self->{dbname} = shift @args ;
  $self->{user}   = shift @args || "" ;
  $self->{pwd}    = shift @args || "" ;

  # The old Sybase server
  # my $dbh = DBI->connect(":Sybase:server=$self->{dbname}",
  #                        $self->{user},
  #                        $self->{pwd},
  #                        {PrintError=>1}) ;

  unless (-e $self->{dbname}) {
    _create_db($self->{dbname}, $self->{user}, $self->{pwd}) ;
  }

  my $dbh = DBI->connect("dbi:SQLite:dbname=$self->{dbname}", $self->{user}, $self->{pwd}) ;
  unless ($dbh) {
    $msg = "Unable to create SQLite database: " . $DBI::errstr ;
    log->fatal($msg) ;
    die $msg, "\n";
  }
  $self->{dbh} = $dbh ;

  bless($self, $class) ;

} # end new

=head2 _printme

 Print the object (for testing).

=cut

sub _printme {
  use Data::Dumper ;
  my $self = shift ;

  print Dumper $self, "\n\n" ;
}

=head2 _create_db

  Create a suitable database for snpdoc.

  Accepts: Scalar with the database name.
  Returns: Status

=cut

sub _create_db{
  my $log = Log::Log4perl->get_logger("_create_db") ;
  my $msg = "" ;

  $msg = "In _create_db" ;
  $log->debug($msg) ;

  my ($dbname, $user, $pwd) = @_ ;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", $user, $pwd) ;

  my $sql = <<END;
create table variation (
  type varchar(255),
  name varchar(255),
  chr  varchar(2),
  pos1 int,
  pos2 int,
  ncbi_url varchar(255),
  ucsc_url varchar(255),
  chr_url varchar(255),
  near_gene1 varchar(255),
  gene_url1 varchar(255),
  near_gene2 varchar(255),
  gene_url2 varchar(255),
  gene varchar(255),
  description varchar(255),
  gene_url varchar(255),
  alias varchar(255),
  cons_multiz float,
  cons_phast float,
  risk int,
  cpg varchar(255),
  cnv varchar(255),
  maxclass  varchar(255),
  version int,
  merged_to varchar(255),
  date_inserted varchar(25)
) ;
END

  my $sth = $dbh->prepare($sql) ;
  unless ($sth) {
    $msg = "Could not prepare sql (create table ...)" ;
    $msg .= $dbh->errstr() ;
    $log->fatal($msg) ;
    die $msg, "\n" ;
  }

  my $rv = $sth->execute() ;
  unless ($rv) {
    $msg = "Could not execute sql (create table ...) " ;
    $msg .= $dbh->errstr() ;
    $log->fatal($msg) ;
    die $msg, "\n" ;
  }

  $dbh->disconnect() ;

  $log->info("Created table \"variation\" in database $dbname.") ;

  return 1 ;
} # end _create_db

sub trim {
  my $line = shift ;

  $line =~ s/[\r\n]+//g ;
  $line =~ s/^\s+// ;
  $line =~ s/\s+$// ;

  return $line ;
} # end trim


=head2 load

Load database information from supplied file.  Deprecated; now done
in the constructor.

=cut

sub load {
  my $log = Log::Log4perl->get_logger("load") ;
  my $self = shift ;
  my $config_file = shift ;

  unless ($config_file) {
    $log->fatal("Load called without a configuration file.") ;
    die("[DBWrite::load] error 3: Must pass a config file to DBWrite.") ;
  }

  # Read the param file passed in.
  unless (open(CONF, $config_file) ) {
    $log->fatal("Could not open $config_file.") ;
    die("[DBWrite::load] Config file failed to open\n") ;
  }

  my %param = () ;
 LINE:
  while (my $line = <CONF>) {
    chomp $line ;
    $line =~ s/\#.*$// ;
    next LINE if $line =~ m/^\s*$/ ;

    my ($key, $val) = split(/=/, $line) ;
    $key = trim($key) ;
    $val = trim($val) ;
    $param{$key} = $val ;
  }

  $self->{dbname}   = $param{dbname} ;
  $self->{username} = $param{user} ;
  $self->{pwd}      = $param{pwd} ;

  $self->{dbname} = "  " ;

  $self->prep_db ;

}  # end load

=head2 prep_db

Prepare a database connection. Deprecated; now done in the
constructor.

=cut

sub prep_db{
  my $log = Log::Log4perl->get_logger("prep_db") ;
  my $msg ;
  my $self = shift ;

  unless ($self->{dbname} and $self->{user} and $self->{pwd} ) {
    $msg = "Called with invalid db info." ;
    $log->fatal($msg) ;
    die $msg, "\n" ;
  }

  my $dbh = DBI->connect("DBI:Sybase:server=$self->{dbname}",
                         $self->{user},
                         $self->{pwd},
                         {PrintError=>1}) ;

  die("[DBWRITE::prep_db] error 2: Unable to connect to server:  $DBI::errstr")
    unless($dbh) ;

  $self->{handle} = $dbh ;

}  # DBWrite->prep_db()

=head2 put

Write data to the database.

=cut

sub put{
  my $log = Log::Log4perl->get_logger("put") ;
  my $msg = "" ;

  $msg = "In put." ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;

  unless ($data) {
    $msg = "Configuration file not passed to put." ;
    $log->fatal($msg) ;
    die("[DBWrite::put] error 3: $msg\n") ;
  }

  # Handle created in the previous method
  my $dbh = $self->{dbh} ;
  $self->prep_db
    unless($dbh) ;

  # Get all elts.
  my $marker = $data->marker_text ; # may contain '(new) merged into (old)'.
  $log->debug("Processing marker: $marker.");

  my $merged_to = "" ;
  if ($marker =~ m/(rs\d+)\s+merged\sinto\s+(rs\d+)/) {
    $merged_to = $2 ;
    $marker = $1 ;
  }

  my $type        = $data->type ;
  my $url         = $data->URL ;
  my $ucscurl     = $data->UCSC_URL ;
  my $snp_chr     = $data->chromosome ;
  my $chrlink     = $data->Chr_URL ;
  my $snp_pos     = $data->position ;
  my $near_gene1  = $data->near_gene_text_u ;
  my $gene_link1  = $data->near_gene_link_u ;
  my $near_gene2  = $data->near_gene_text_d ;
  my $gene_link2  = $data->near_gene_link_d ;
  my $gene        = $data->gene ;
  my $description = $data->description ;
  my $geneURL     = $data->gene_URL ;
  my $alias       = $data->alias ;
  my $multiz      = $data->cons_multiz ;
  my $phast       = $data->cons_phast ;
  my $maxrisk     = $data->risk ;
  my $maxclass    = $data->classification ;
  my $version     = $data->version ;
  my $cpg         = $data->CpG ;
  my $cnv         = $data->CNV ;

  # need to handle this more appropriately; e.g. do we need to convert single ' to "-prime"
  $type        =~ s/['"]//g ;
  $url         =~ s/['"]//g ;
  $ucscurl     =~ s/['"]//g ;
  $snp_chr     =~ s/['"]//g ;
  $chrlink     =~ s/['"]//g ;
  $snp_pos     =~ s/['"]//g ;
  $near_gene1  =~ s/['"]//g ;
  $gene_link1  =~ s/['"]//g ;
  $near_gene2  =~ s/['"]//g ;
  $gene_link2  =~ s/['"]//g ;
  $gene        =~ s/['"]//g ;
  $gene        =~ s/['"]//g ;
  $description =~ s/['"]//g ;
  $geneURL     =~ s/['"]//g ;
  $alias       =~ s/['"]//g ;
  $multiz      =~ s/['"]//g ;
  $phast       =~ s/['"]//g ;
  $maxrisk     =~ s/['"]//g ;
  $maxclass    =~ s/['"]//g ;
  $version     =~ s/['"]//g ;
  $cpg         =~ s/['"]//g ;
  $cnv         =~ s/['"]//g ;


  # Add a second level of checking if we have notfound UCSC.
  if ($near_gene1 =~ m/Error/) {
    if ($self->check_more_accurate($marker, $version)) {
      print "Not writing to db.\n" ;
      return ;
    }
  }

# The following is the insert statement for the WFU Sybase Database
# (wrapped for clarity)

# my $sql = qq{exec spInsertSNPDoc
# '$marker', '$url', '$ucscurl', '$snp_chr', '$chrlink', '$snp_pos',
# '$near_gene1', '$gene_link1','$near_gene2', '$gene_link2',
# '$gene', '$description', '$geneURL', '$alias', '$maxrisk', '$cpg','$cnv',
# '$maxclass','$version','$merged_to'} ;

my $now = strftime "%Y-%m-%d %H:%M:%S", localtime ;

my $sql = <<SQL ;
insert into variation (type,    name,     ncbi_url, ucsc_url,   chr,       chr_url,     pos1,       near_gene1,   gene_url1,    near_gene2,   gene_url2,    gene,   description,   gene_url,  alias,   cons_multiz, risk,        cpg,   cnv,   maxclass,   version,   merged_to,   date_inserted )
values (              '$type', '$marker', '$url',  '$ucscurl', '$snp_chr', '$chrlink ','$snp_pos','$near_gene1','$gene_link1','$near_gene2','$gene_link2','$gene','$description','$geneURL','$alias', '$multiz',   '$maxrisk', '$cpg','$cnv','$maxclass','$version','$merged_to', '$now') ;

SQL

  $log->debug($sql) ;

  my $sth = $dbh->prepare($sql) ;
  unless (defined $sth) {
    $msg = "Could not prepare query: " . $dbh->errstr ;
    $log->fatal($msg) ;
    die "[DBWrite::put] ", $msg, "\n" ;
  }

  ### this is the craziest thing I have ever seen.  I'm keeping it
  ### (didn't write it) because it has the appearance of genius.  or
  ### mania. ###

  my $success = 1 ;
  $success &&= $sth->execute()
    or die "[DBWrite::put] error 2: $DBI::errstr, $dbh->errstr" ;

  if ($@) {                     # EVAL_ERROR (?)
    $log->warn("Database error: $DBI::errstr.") ;
    warn "[DBWrite::put] Database error: $DBI::errstr\n cannot finish transaction " . $dbh->errstr . "\n"  ;
    $dbh->rollback ;
  }
  $sth->finish() ;

} # end DBWrite->put()

=head2 check_more_accurate

Check that an eroneous row does not overwrite a good row.  Return 1
if we should write the current row and 0 if not.

=cut

sub check_more_accurate{
  my $log = Log::Log4perl->get_logger("check_more_accurate") ;
  my $msg = "In check_more_accurate." ;
  $log->debug($msg) ;

  my $self   = shift ;
  my $marker = shift ;
  my $build  = shift ;
  my $dbh    = $self->{dbh} ;

  # Following statement is for the WFU Sybase database.  Field
  # 'geneurltext1' corresponds to 'near_gene1' in the SNPData data
  # structure.
  # my $sth = $dbh->prepare("select geneurltext1 from  _sysSnpDoc where marker = '$marker' and build = '$build' ") ;

  $build = "hg" . $build ;
  my $sth = $dbh->prepare("select near_gene1 from variation where name = '$marker' and version = '$build' ") ;

  unless ($sth->execute()) {
    $msg = "Could not connect to database: $dbh->errstr." ;
    $log->fatal($msg) ;
    die "[DBWrite::check_more_accurate] $msg\n" ;
  }

  while (my @data = $sth->fetchrow_array()) {
    return 1 if($data[0] !~ m/Error/) ;
  }

  return 0 ;

} # DBWrite->check_more_accurate


=head2 snp_in_db

 Check the database for existance of a feature.

 Accepts: Scalar with snp name.
 Returns: Status

=cut

sub snp_in_db {
  my $log = Log::Log4perl->get_logger("snp_in_db") ;
  my $msg = "In snp_in_db" ;
  $log->debug($msg) ;

  my $self   = shift ;
  my $snp    = shift ;
  my $db_ver = shift ;

  $msg = "Called with snp=$snp and db_ver=$db_ver." ;
  $log->debug($msg) ;

  my $dbh  = $self->{dbh} ;
  my $status = 0 ;

  my $sql = "select name from variation where name = ? and version = ?" ;
  my $sth = $dbh->prepare($sql) ;
  if (!$sth->execute($snp, $db_ver)) {
    $msg = "Problem executing query, continuing. " ;
    $msg .= $dbh->errstr ;
  } else {
    my $row = $sth->fetch ;
    $status++ if $row->[0] ;
  }

  $msg = "Returning status=$status." ;
  $log->debug($msg) ;

  return $status ;

} # end snp_in_db

=head2 position_in_db

 Check the database for existance of a feature using
 positional information.

 Accepts: Scalars with position.
 Returns: Status

=cut

sub position_in_db {
  my $log = Log::Log4perl->get_logger("position_in_db") ;
  my $msg = "In position_in_db" ;
  $log->debug($msg) ;

  my $self   = shift ;
  my $chr    = shift ;
  my $pos    = shift ;
  my $db_ver = shift ;

  my $dbh  = $self->{dbh} ;
  my $status = 0 ;

  $msg = "Preparing sql with chr=$chr, pos=$pos, db_ver=$db_ver." ;
  $log->debug($msg) ;

  my $sql = "select name from variation where chr = ? and pos1 = ? and version = ?" ;
  my $sth = $dbh->prepare($sql) ;
  if (!$sth->execute($chr, $pos, $db_ver)) {
    $msg = "Problem executing query, continuing. " ;
    $msg .= $dbh->errstr ;
  } else {
    my $row = $sth->fetch ;
    $status = $row->[0] || 0 ;
  }

  $msg = "Returning with status=$status." ;
  $log->debug($msg) ;

  return $status ;

} # end position_in_db

=head2 fill_data

 Fill the SNPData structure with data from the database.

 Accepts: Scalar with snp name
 Returns: Status

=cut

sub fill_data {
  my $log = Log::Log4perl->get_logger("fill_data") ;
  my $msg = "In fill_data" ;
  $log->debug($msg) ;

  my $self = shift ;
  my $data = shift ;
  my $snp  = shift ;

  my $dbh  = $self->{dbh} ;
  my $status = 0 ;

  my $sql = "select * from variation where name = ?" ;
  my $sth = $dbh->prepare($sql) ;

  my $aref ;
  if (!$sth->execute($snp)) {
    $msg = "Problem executing query, continuing. " ;
    $msg .= $dbh->errstr ;
    return $status ;
  } else {
    $aref = $sth->fetch ;
  }

  $data->type($aref->[0]) ;
  $data->marker($aref->[1]) ;
  $data->chromosome($aref->[2]) ;
  $data->position($aref->[3]) ;
  # skip $aref->[4], pos2
  $data->URL($aref->[5]) ;
  $data->UCSC_URL($aref->[6]) ;
  $data->Chr_URL($aref->[7]) ;
  $data->near_gene_u($aref->[8]) ;
  $data->near_gene_link_u($aref->[9]) ;
  $data->near_gene_d($aref->[10]) ;
  $data->near_gene_link_d($aref->[11]) ;
  $data->gene($aref->[12]) ;
  $data->description($aref->[13]) ;
  $data->gene_URL($aref->[14]) ;
  $data->alias($aref->[15]) ;
  $data->cons_multiz($aref->[16]) ;
  # skip $aref->[17], cons_phast
  $data->risk($aref->[18]) ;
  $data->CpG($aref->[19]) ;
  $data->CNV($aref->[20]) ;
  $data->classification($aref->[21]) ;
  $data->version($aref->[22]) ;
  # skip $aref->[23] merged_to

  $status++ ;
  return $status ;
} # end fill_data

return 1 ;
