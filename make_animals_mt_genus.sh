#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND (mitochondrion[Filter] OR mitochondrial[Filter]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' animals_mt.txt || exit $?
# make taxonomy database
#clmaketaxdb --includetaxid=33208 taxonomy animals.taxdb || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=animals_mt.txt --taxdb=animals.taxdb animals_mt_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../animals_mt_genus.txt -out animals_mt_genus -title animals_mt_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../animals_mt_species.txt -out animals_mt_species -title animals_mt_species 2> /dev/null || exit $?
#
blastdbcmd -db ./animals_mt_genus -target_only -entry all -out ../animals_mt_genus.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=animals_mt_genus.txt taxonomy animals_mt_genus.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species.taxdb || exit $?
#rm animals.taxdb || exit $?
#rm blastdb/animals_genus.* || exit $?
