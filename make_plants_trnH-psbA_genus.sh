#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33090[Organism:exp] AND 200:10000[Sequence Length] AND ("trnH-psbA"[Title] OR ((trnH[Title] OR "tRNA-His"[Title]) AND psbA[Title])) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' plants_trnH-psbA1.txt || exit $?
cat plants_cpgenomes.txt >> plants_trnH-psbA1.txt || exit $?
# make taxonomy database
#clmaketaxdb --includetaxid=33090 taxonomy plants.taxdb || exit $?
# search by keywords at taxdb
#clretrievegi --includetaxa=genus,.+ --ngwords=environmental,uncultured,unclassified,unidentified --taxdb=plants.taxdb plants_genus.txt || exit $?
# make BLAST database
#cd blastdb || exit $?
#blastdb_aliastool -dbtype nucl -db ./nt -gilist ../plants_genus.txt -out plants_genus -title plants_genus || exit $?
#cd .. || exit $?
# search by reference sequences
clblastseq blastn -db blastdb/plants_genus -word_size 11 -evalue 1e-15 -strand plus -task blastn -max_target_seqs 1000000000 end --numthreads=8 --hyperthreads=2 references_plants_trnH-psbA.fasta plants_trnH-psbA2.txt || exit $?
# eliminate duplicate entries
clelimdupgi plants_trnH-psbA1.txt plants_trnH-psbA2.txt plants_trnH-psbA.txt || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../plants_trnH-psbA_genus.txt -out plants_trnH-psbA_genus -title plants_trnH-psbA_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../plants_trnH-psbA_species.txt -out plants_trnH-psbA_species -title plants_trnH-psbA_species 2> /dev/null || exit $?
#
clblastdbcmd --blastdb=./plants_trnH-psbA_genus --output=GI --numthreads=8 ../plants_trnH-psbA_genus.txt plants_trnH-psbA_genus.txt || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=blastdb/plants_trnH-psbA_genus.txt taxonomy plants_trnH-psbA_genus.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species.taxdb || exit $?
#rm plants.taxdb || exit $?
#rm blastdb/plants_genus.* || exit $?
