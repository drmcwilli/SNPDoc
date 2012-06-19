-- test_variation_load.sql
-- Stuf to get the sql correct.
-- DRM 14-Oct-2011

insert into variation (type,    name,     ncbi_url, ucsc_url,   snp_chr,     chr_url,   pos1,       near_gene1,   gene_url1,    near_gene2,   gene_url2,    gene,   description,   gene_url,  alias,   cons_multiz, risk,        cpg,   cnv,   maxclass,   version,   merged_to )
values ('snp',   'rs1234', 'this.org', 'that.org', '22',     'chr.ling',   '123',  'YFG',           'yfg.link',   'MFG',        'mfg.link',    'ABC1',  'The reading gene', 'abc1.org', 'XYZ', '0.1234', '1', '1', 'CNV1', 'In intron', 'hg99', 'rs789') ;

-- '$type', '$marker','$url',    '$ucscurl', '$snp_chr', '$chrlink ','$snp_pos','$near_gene1','$gene_link1','$near_gene2','$gene_link2','$gene','$description','$geneURL','$alias', '$multiz',   '$maxrisk', '$cpg','$cnv','$maxclass','$version','$merged_to')
