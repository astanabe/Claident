#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND 200:10000[Sequence Length] AND ("cytochrome c oxidase subunit 1"[Title] OR "cytochrome c oxydase subunit 1"[Title] OR "cytochrome c oxidase subunit I"[Title] OR "cytochrome c oxydase subunit I"[Title] OR "cytochrome oxidase subunit 1"[Title] OR "cytochrome oxydase subunit 1"[Title] OR "cytochrome oxidase subunit I"[Title] OR "cytochrome oxydase subunit I"[Title] OR COX1[Title] OR CO1[Title] OR COI[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' animals_COX11.txt || exit $?
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND "complete genome"[Title] AND mitochondrion[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title])' animals_mitogenomes.txt || exit $?
wait
cat animals_mitogenomes.txt >> animals_COX11.txt || exit $?
# make taxonomy database
clmaketaxdb --includetaxid=33208 taxonomy animals.taxdb || exit $?
# search by keywords at taxdb
clretrievegi --includetaxa=genus,.+ --ngwords=environmental,uncultured,unclassified,unidentified --taxdb=animals.taxdb animals_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
blastdb_aliastool -dbtype nucl -db ./nt -gilist ../animals_genus.txt -out animals_genus -title animals_genus || exit $?
cd .. || exit $?
# search by reference sequences
clblastseq blastn -db blastdb/animals_genus -word_size 9 -evalue 1e-5 -strand plus -task blastn -max_target_seqs 1000000000 end --numthreads=8 --hyperthreads=2 references_animals_COX1.fasta animals_COX12.txt || exit $?
# eliminate duplicate entries
clelimdupgi animals_COX11.txt animals_COX12.txt animals_COX1.txt || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --gilist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --gilist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../animals_COX1_genus.txt -out animals_COX1_genus -title animals_COX1_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../animals_COX1_species.txt -out animals_COX1_species -title animals_COX1_species 2> /dev/null || exit $?
#
clblastdbcmd --blastdb=./animals_COX1_genus --output=GI --numthreads=8 ../animals_COX1_genus.txt animals_COX1_genus.txt || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=animals_COX1_genus.txt taxonomy animals_COX1_genus.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species.taxdb || exit $?
