#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33090[Organism:exp] AND 200:10000[Sequence Length] AND (rbcL[Title] OR ((RuBisCO[Title] OR (ribulose[Title] AND bisphosphate[Title] AND carboxylase[Title] AND oxygenase[Title])) AND "large subunit"[Title])) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' plants_rbcL1.txt || exit $?
cat plants_cpgenomes.txt >> plants_rbcL1.txt || exit $?
# make taxonomy database
#clmaketaxdb --includetaxid=33090 taxonomy plants.taxdb || exit $?
# search by keywords at taxdb
#clretrievegi --includetaxa=genus,.+ --ngwords=environmental,uncultured,unclassified,unidentified --taxdb=plants.taxdb plants_genus.txt || exit $?
# make BLAST database
#cd blastdb || exit $?
#blastdb_aliastool -dbtype nucl -db ./nt -gilist ../plants_genus.txt -out plants_genus -title plants_genus || exit $?
#cd .. || exit $?
# search by reference sequences
clblastseq blastn -db blastdb/plants_genus -word_size 11 -evalue 1e-15 -strand plus -task blastn -max_target_seqs 1000000000 end --numthreads=8 --hyperthreads=2 references_plants_rbcL.fasta plants_rbcL2.txt || exit $?
# eliminate duplicate entries
clelimdupgi plants_rbcL1.txt plants_rbcL2.txt plants_rbcL.txt || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=plants_rbcL.txt --taxdb=plants.taxdb plants_rbcL_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=plants_rbcL.txt --taxdb=plants.taxdb plants_rbcL_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../plants_rbcL_genus.txt -out plants_rbcL_genus -title plants_rbcL_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../plants_rbcL_species.txt -out plants_rbcL_species -title plants_rbcL_species 2> /dev/null || exit $?
#
blastdbcmd -db ./plants_rbcL_genus -target_only -entry all -out ../plants_rbcL_genus.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=plants_rbcL_genus.txt taxonomy plants_rbcL_genus.taxdb || exit $?
ln -s plants_rbcL_genus.taxdb plants_rbcL_species.taxdb || exit $?
