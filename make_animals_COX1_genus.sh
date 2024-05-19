#!/bin/sh
# Set number of processor cores used for computation
export NCPU=0; for n in `grep cpu.cores /proc/cpuinfo | grep -o -P '\d+' | sort -u`; do NCPU=$(($NCPU + n)); done
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND 150:50000[Sequence Length] AND ("cytochrome c oxidase subunit 1"[Title] OR "cytochrome c oxydase subunit 1"[Title] OR "cytochrome c oxidase subunit I"[Title] OR "cytochrome c oxydase subunit I"[Title] OR "cytochrome oxidase subunit 1"[Title] OR "cytochrome oxydase subunit 1"[Title] OR "cytochrome oxidase subunit I"[Title] OR "cytochrome oxydase subunit I"[Title] OR COX1[Title] OR CO1[Title] OR COI[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' animals_COX11.txt &
#clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND "complete genome"[Title] AND mitochondrion[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' animals_mitogenomes.txt &
wait
cat animals_mitogenomes.txt >> animals_COX11.txt || exit $?
# make taxonomy database
#clmaketaxdb --excluderefseq=enable --includetaxid=33208 taxonomy animals.taxdb || exit $?
# search by keywords at taxdb
#clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=animals.taxdb animals_genus.txt || exit $?
# make BLAST database
#cd blastdb || exit $?
#clblastdbcmd --blastdb=`pwd`/nt --output=ACCESSION --numthreads=$NCPU ../animals_genus.txt animals_genus.txt
#BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in animals_genus.txt -seqid_title animals_genus -seqid_file_out animals_genus.bsl || exit $?
#BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db nt -seqidlist animals_genus.bsl -out animals_genus -title animals_genus || exit $?
#cd .. || exit $?
# search by reference sequences
clblastseq blastn -db `pwd`/blastdb/animals_genus -word_size 9 -evalue 1e-5 -strand plus -task blastn -max_target_seqs 10000000 end --output=ACCESSION --numthreads=8 --hyperthreads=16 references_animals_COX1.fasta animals_COX12.txt || exit $?
# eliminate duplicate entries
clelimdupacc animals_COX11.txt animals_COX12.txt animals_COX1.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_COX1.txt --taxdb=animals.taxdb animals_COX1_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_genus.txt animals_COX1_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_species_wsp.txt animals_COX1_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_species.txt animals_COX1_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_species_wosp.txt animals_COX1_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_genus_man.txt animals_COX1_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_species_wsp_man.txt animals_COX1_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_species_man.txt animals_COX1_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_COX1_species_wosp_man.txt animals_COX1_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_genus.txt -seqid_title animals_COX1_genus -seqid_file_out animals_COX1_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_genus.bsl -out animals_COX1_genus -title animals_COX1_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species_wsp.txt -seqid_title animals_COX1_species_wsp -seqid_file_out animals_COX1_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species_wsp.bsl -out animals_COX1_species_wsp -title animals_COX1_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species.txt -seqid_title animals_COX1_species -seqid_file_out animals_COX1_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species.bsl -out animals_COX1_species -title animals_COX1_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species_wosp.txt -seqid_title animals_COX1_species_wosp -seqid_file_out animals_COX1_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species_wosp.bsl -out animals_COX1_species_wosp -title animals_COX1_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_genus_man.txt -seqid_title animals_COX1_genus_man -seqid_file_out animals_COX1_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_genus_man.bsl -out animals_COX1_genus_man -title animals_COX1_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species_wsp_man.txt -seqid_title animals_COX1_species_wsp_man -seqid_file_out animals_COX1_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species_wsp_man.bsl -out animals_COX1_species_wsp_man -title animals_COX1_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species_man.txt -seqid_title animals_COX1_species_man -seqid_file_out animals_COX1_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species_man.bsl -out animals_COX1_species_man -title animals_COX1_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_COX1_species_wosp_man.txt -seqid_title animals_COX1_species_wosp_man -seqid_file_out animals_COX1_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_COX1_species_wosp_man.bsl -out animals_COX1_species_wosp_man -title animals_COX1_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/animals_COX1_genus.txt blastdb/animals_COX1_species_wsp.txt blastdb/animals_COX1_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/animals_COX1_genus.temp taxonomy animals_COX1_genus.taxdb || exit $?
chmod 666 animals_COX1_genus.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species_wsp.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species_wosp.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_genus_man.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species_wsp_man.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species_man.taxdb || exit $?
ln -s animals_COX1_genus.taxdb animals_COX1_species_wosp_man.taxdb || exit $?
