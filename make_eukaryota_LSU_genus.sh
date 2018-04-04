#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid2759[Organism:exp] AND 200:10000[Sequence Length] AND ((25S[Title] OR 26S[Title] OR 27S[Title] OR 28S[Title] OR "large subunit"[Title] OR LSU[Title]) AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' eukaryota_LSU.txt || exit $?
# make taxonomy database
clmaketaxdb --gilist=eukaryota_LSU.txt taxonomy eukaryota_LSU_temp.taxdb || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=eukaryota_LSU.txt --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=eukaryota_LSU.txt --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../eukaryota_LSU_genus.txt -out eukaryota_LSU_genus -title eukaryota_LSU_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../eukaryota_LSU_species.txt -out eukaryota_LSU_species -title eukaryota_LSU_species 2> /dev/null || exit $?
#
clblastdbcmd --blastdb=./eukaryota_LSU_genus --output=GI --numthreads=8 ../eukaryota_LSU_genus.txt eukaryota_LSU_genus.txt || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=blastdb/eukaryota_LSU_genus.txt taxonomy eukaryota_LSU_genus.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species.taxdb || exit $?
rm eukaryota_LSU_temp.taxdb || exit $?
