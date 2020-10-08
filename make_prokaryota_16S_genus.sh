#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND ((txid2[Organism:exp] OR txid2157[Organism:exp]) AND 200:10000[Sequence Length] AND (16S[Title] AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' prokaryota_16S.txt || exit $?
# make taxonomy database
#clmaketaxdb --includetaxid=2,2157 taxonomy prokaryota.taxdb || exit $?
# extract genus-level identified sequences
clretrieveacc --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_genus.txt || exit $?
# extract species-level identified sequences
clretrieveacc --includetaxa=genus,.+,species,.+ --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but prokaryota_all_genus-dependent
clextractdupacc --workspace=disk overall_underclass.txt ../prokaryota_16S_genus.txt prokaryota_16S_genus.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../prokaryota_16S_species.txt prokaryota_16S_species.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_genus.txt -seqid_title prokaryota_16S_genus -seqid_file_out prokaryota_16S_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_genus.bsl -out prokaryota_16S_genus -title prokaryota_16S_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species.txt -seqid_title prokaryota_16S_species -seqid_file_out prokaryota_16S_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species.bsl -out prokaryota_16S_species -title prokaryota_16S_species" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/prokaryota_16S_genus.txt taxonomy prokaryota_16S_genus.taxdb
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species.taxdb || exit $?
#rm prokaryota.taxdb || exit $?
