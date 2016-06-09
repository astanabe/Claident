#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid2759[Organism:exp] AND 200:10000[Sequence Length] AND ((18S[Title] OR "small subunit"[Title] OR SSU[Title]) AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' eukaryota_SSU.txt || exit $?
# make taxonomy database
clmaketaxdb --gilist=eukaryota_SSU.txt taxonomy eukaryota_SSU_temp.taxdb || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=eukaryota_SSU.txt --taxdb=eukaryota_SSU_temp.taxdb eukaryota_SSU_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=eukaryota_SSU.txt --taxdb=eukaryota_SSU_temp.taxdb eukaryota_SSU_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../eukaryota_SSU_genus.txt -out eukaryota_SSU_genus -title eukaryota_SSU_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../eukaryota_SSU_species.txt -out eukaryota_SSU_species -title eukaryota_SSU_species 2> /dev/null || exit $?
#
blastdbcmd -db ./eukaryota_SSU_genus -target_only -entry all -out ../eukaryota_SSU_genus.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=eukaryota_SSU_genus.txt taxonomy eukaryota_SSU_genus.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species.taxdb || exit $?
rm eukaryota_SSU_temp.taxdb || exit $?
