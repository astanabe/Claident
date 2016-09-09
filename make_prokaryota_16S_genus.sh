#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND ((txid2[Organism:exp] OR txid2157[Organism:exp]) AND 200:10000[Sequence Length] AND (16S[Title] AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' prokaryota_16S.txt || exit $?
# make taxonomy database
#clmaketaxdb --includetaxid=2,2157 taxonomy prokaryota.taxdb || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but prokaryota_all_genus-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../prokaryota_16S_genus.txt -out prokaryota_16S_genus -title prokaryota_16S_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../prokaryota_16S_species.txt -out prokaryota_16S_species -title prokaryota_16S_species 2> /dev/null || exit $?
#
blastdbcmd -db ./prokaryota_16S_genus -target_only -entry all -out ../prokaryota_16S_genus.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=prokaryota_16S_genus.txt taxonomy prokaryota_16S_genus.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species.taxdb || exit $?
#rm prokaryota.taxdb || exit $?
