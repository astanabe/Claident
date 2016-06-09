#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33090[Organism:exp] AND 200:10000[Sequence Length] AND (matK[Title] OR "maturase K"[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' plants_matK1.txt || exit $?
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33090[Organism:exp] AND "complete genome"[Title] AND chloroplast[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' plants_cpgenomes.txt || exit $?
cat plants_cpgenomes.txt >> plants_matK1.txt || exit $?
# make taxonomy database
clmaketaxdb --includetaxid=33090 taxonomy plants.taxdb || exit $?
# search by keywords at taxdb
clretrievegi --includetaxa=genus,.+ --ngwords=environmental,uncultured,unclassified,unidentified --taxdb=plants.taxdb plants_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
blastdb_aliastool -dbtype nucl -db ./nt -gilist ../plants_genus.txt -out plants_genus -title plants_genus || exit $?
cd .. || exit $?
# search by reference sequences
clblastseq blastn -db blastdb/plants_genus -word_size 11 -evalue 1e-15 -strand plus -task blastn -max_target_seqs 1000000000 end --numthreads=8 --hyperthreads=2 references_plants_matK.fasta plants_matK2.txt || exit $?
# eliminate duplicate entries
clelimdupgi plants_matK1.txt plants_matK2.txt plants_matK.txt || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=plants_matK.txt --taxdb=plants.taxdb plants_matK_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=plants_matK.txt --taxdb=plants.taxdb plants_matK_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../plants_matK_genus.txt -out plants_matK_genus -title plants_matK_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../plants_matK_species.txt -out plants_matK_species -title plants_matK_species 2> /dev/null || exit $?
#
blastdbcmd -db ./plants_matK_genus -target_only -entry all -out ../plants_matK_genus.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=plants_matK_genus.txt taxonomy plants_matK_genus.taxdb || exit $?
ln -s plants_matK_genus.taxdb plants_matK_species.taxdb || exit $?
