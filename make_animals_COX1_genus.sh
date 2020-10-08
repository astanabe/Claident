#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND 200:10000[Sequence Length] AND ("cytochrome c oxidase subunit 1"[Title] OR "cytochrome c oxydase subunit 1"[Title] OR "cytochrome c oxidase subunit I"[Title] OR "cytochrome c oxydase subunit I"[Title] OR "cytochrome oxidase subunit 1"[Title] OR "cytochrome oxydase subunit 1"[Title] OR "cytochrome oxidase subunit I"[Title] OR "cytochrome oxydase subunit I"[Title] OR COX1[Title] OR CO1[Title] OR COI[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' animals_COX11.txt &
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND "complete genome"[Title] AND mitochondrion[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' animals_mitogenomes.txt &
wait
cat animals_mitogenomes.txt >> animals_COX11.txt || exit $?
# make taxonomy database
clmaketaxdb --includetaxid=33208 taxonomy animals.taxdb || exit $?
# search by keywords at taxdb
clretrieveacc --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=animals.taxdb animals_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
clblastdbcmd --blastdb=./nt --output=ACCESSION --numthreads=8 ../animals_genus.txt animals_genus.txt
BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in animals_genus.txt -seqid_title animals_genus -seqid_file_out animals_genus.bsl || exit $?
BLASTDB=./ blastdb_aliastool -dbtype nucl -db nt -seqidlist animals_genus.bsl -out animals_genus -title animals_genus || exit $?
cd .. || exit $?
# search by reference sequences
clblastseq blastn -db blastdb/animals_genus -word_size 9 -evalue 1e-5 -strand plus -task blastn -max_target_seqs 1000000000 end --output=ACCESSION --numthreads=8 --hyperthreads=8 references_animals_COX1.fasta animals_COX12.txt || exit $?
# eliminate duplicate entries
clelimdupacc animals_COX11.txt animals_COX12.txt animals_COX1.txt || exit $?
# extract genus-level identified sequences
clretrieveacc --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_genus.txt || exit $?
# extract species-level identified sequences
clretrieveacc --includetaxa=genus,.+,species,.+ --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_underclass.txt ../animals_COX1_genus.txt animals_COX1_genus.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../animals_COX1_species.txt animals_COX1_species.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_genus.txt -seqid_title animals_COX1_genus -seqid_file_out animals_COX1_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_genus.bsl -out animals_COX1_genus -title animals_COX1_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species.txt -seqid_title animals_COX1_species -seqid_file_out animals_COX1_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species.bsl -out animals_COX1_species -title animals_COX1_species" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/animals_COX1_genus.txt taxonomy animals_COX1_genus.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species.taxdb || exit $?
