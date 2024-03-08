#!/bin/sh
# Set number of processor cores used for computation
export NCPU=`grep -c processor /proc/cpuinfo`
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid7711[Organism:exp] AND 150:20000[Sequence Length] AND (12S[Title] AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' fishes_12S1.txt &
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid7711[Organism:exp] AND "complete genome"[Title] AND mitochondrion[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' fishes_mitogenomes.txt &
wait
cat fishes_mitogenomes.txt >> fishes_12S1.txt || exit $?
# make taxonomy database
clmaketaxdb --excluderefseq=enable --includetaxid=7711 taxonomy fishes.taxdb || exit $?
# search by keywords at taxdb
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fishes.taxdb fishes_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
clblastdbcmd --blastdb=`pwd`/nt --output=ACCESSION --numthreads=$NCPU ../fishes_genus.txt fishes_genus.txt
BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in fishes_genus.txt -seqid_title fishes_genus -seqid_file_out fishes_genus.bsl || exit $?
BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db nt -seqidlist fishes_genus.bsl -out fishes_genus -title fishes_genus || exit $?
cd .. || exit $?
# search by reference sequences
clblastseq blastn -db `pwd`/blastdb/fishes_genus -word_size 9 -evalue 1e-5 -strand plus -task blastn -max_target_seqs 10000000 end --output=ACCESSION --numthreads=$NCPU --hyperthreads=8 references_fishes_12S.fasta fishes_12S2.txt || exit $?
# eliminate duplicate entries
clelimdupacc fishes_12S1.txt fishes_12S2.txt fishes_12S.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fishes_12S.txt --taxdb=fishes.taxdb fishes_12S_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_genus.txt fishes_12S_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_species_wsp.txt fishes_12S_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_species.txt fishes_12S_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_species_wosp.txt fishes_12S_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_genus_man.txt fishes_12S_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_species_wsp_man.txt fishes_12S_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_species_man.txt fishes_12S_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fishes_12S_species_wosp_man.txt fishes_12S_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_genus.txt -seqid_title fishes_12S_genus -seqid_file_out fishes_12S_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_genus.bsl -out fishes_12S_genus -title fishes_12S_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_species_wsp.txt -seqid_title fishes_12S_species_wsp -seqid_file_out fishes_12S_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_species_wsp.bsl -out fishes_12S_species_wsp -title fishes_12S_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_species.txt -seqid_title fishes_12S_species -seqid_file_out fishes_12S_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_species.bsl -out fishes_12S_species -title fishes_12S_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_species_wosp.txt -seqid_title fishes_12S_species_wosp -seqid_file_out fishes_12S_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_species_wosp.bsl -out fishes_12S_species_wosp -title fishes_12S_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_genus_man.txt -seqid_title fishes_12S_genus_man -seqid_file_out fishes_12S_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_genus_man.bsl -out fishes_12S_genus_man -title fishes_12S_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_species_wsp_man.txt -seqid_title fishes_12S_species_wsp_man -seqid_file_out fishes_12S_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_species_wsp_man.bsl -out fishes_12S_species_wsp_man -title fishes_12S_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_species_man.txt -seqid_title fishes_12S_species_man -seqid_file_out fishes_12S_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_species_man.bsl -out fishes_12S_species_man -title fishes_12S_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fishes_12S_species_wosp_man.txt -seqid_title fishes_12S_species_wosp_man -seqid_file_out fishes_12S_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fishes_12S_species_wosp_man.bsl -out fishes_12S_species_wosp_man -title fishes_12S_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/fishes_12S_genus.txt blastdb/fishes_12S_species_wsp.txt blastdb/fishes_12S_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/fishes_12S_genus.temp taxonomy fishes_12S_genus.taxdb || exit $?
chmod 666 fishes_12S_genus.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_species_wsp.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_species.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_species_wosp.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_genus_man.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_species_wsp_man.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_species_man.taxdb || exit $?
ln -s fishes_12S_genus.taxdb fishes_12S_species_wosp_man.taxdb || exit $?
