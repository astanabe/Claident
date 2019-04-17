#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid4751[Organism:exp] AND 200:10000[Sequence Length] AND (ITS1[Title] OR ITS2[Title] OR "internal transcribed spacer"[Title] OR "internal transcribed spacers"[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' fungi_ITS1.txt || exit $?
# make taxonomy database
clmaketaxdb --includetaxid=4751 taxonomy fungi.taxdb || exit $?
# search by keywords at taxdb
clretrievegi --includetaxa=genus,.+ --ngwords=environmental,uncultured,unclassified,unidentified --taxdb=fungi.taxdb fungi_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
blastdb_aliastool -dbtype nucl -db ./nt -gilist ../fungi_genus.txt -out fungi_genus -title fungi_genus || exit $?
cd .. || exit $?
# search by primer sequences
clblastprimer blastn -db blastdb/fungi_genus -word_size 9 -evalue 1e-1 -perc_identity 90 -strand plus -task blastn-short -ungapped -dust no -max_target_seqs 1000000000 end --numthreads=8 --hyperthreads=2 primers_fungi_ITS.fasta fungi_ITS2.txt || exit $?
# eliminate duplicate entries
clelimdupgi fungi_ITS1.txt fungi_ITS2.txt fungi_ITS.txt || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../fungi_ITS_genus.txt -out fungi_ITS_genus -title fungi_ITS_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../fungi_ITS_species.txt -out fungi_ITS_species -title fungi_ITS_species 2> /dev/null || exit $?
#
clblastdbcmd --blastdb=./fungi_ITS_genus --output=GI --numthreads=8 ../fungi_ITS_genus.txt fungi_ITS_genus.txt || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=blastdb/fungi_ITS_genus.txt taxonomy fungi_ITS_genus.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species.taxdb || exit $?
rm fungi.taxdb || exit $?
rm blastdb/fungi_genus.* || exit $?
