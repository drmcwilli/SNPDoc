-- test_create_var.sql
-- DRM 14-Oct-2011

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
  version varchar(10),
  merged_to varchar(255),
  date_inserted varchar(25)
) ;