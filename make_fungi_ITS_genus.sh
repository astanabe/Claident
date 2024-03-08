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
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid4751[Organism:exp] AND 150:1000000000000[Sequence Length] AND (ITS1[Title] OR ITS2[Title] OR "internal transcribed spacer"[Title] OR "internal transcribed spacers"[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' fungi_ITS1.txt || exit $?
# search by primer sequences
clblastprimer blastn -db `pwd`/blastdb/fungi_all_genus -word_size 9 -evalue 1e-1 -perc_identity 90 -strand plus -task blastn-short -ungapped -dust no -max_target_seqs 100000000 end --numthreads=$NCPU --hyperthreads=8 primers_fungi_ITS.fasta fungi_ITS2.txt || exit $?
# eliminate duplicate entries
clelimdupacc fungi_ITS1.txt fungi_ITS2.txt fungi_ITS.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_genus.txt fungi_ITS_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_wsp.txt fungi_ITS_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species.txt fungi_ITS_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_wosp.txt fungi_ITS_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_genus_man.txt fungi_ITS_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_wsp_man.txt fungi_ITS_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_man.txt fungi_ITS_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_wosp_man.txt fungi_ITS_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_genus.txt -seqid_title fungi_ITS_genus -seqid_file_out fungi_ITS_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_genus.bsl -out fungi_ITS_genus -title fungi_ITS_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_wsp.txt -seqid_title fungi_ITS_species_wsp -seqid_file_out fungi_ITS_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_wsp.bsl -out fungi_ITS_species_wsp -title fungi_ITS_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species.txt -seqid_title fungi_ITS_species -seqid_file_out fungi_ITS_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species.bsl -out fungi_ITS_species -title fungi_ITS_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_wosp.txt -seqid_title fungi_ITS_species_wosp -seqid_file_out fungi_ITS_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_wosp.bsl -out fungi_ITS_species_wosp -title fungi_ITS_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_genus_man.txt -seqid_title fungi_ITS_genus_man -seqid_file_out fungi_ITS_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_genus_man.bsl -out fungi_ITS_genus_man -title fungi_ITS_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_wsp_man.txt -seqid_title fungi_ITS_species_wsp_man -seqid_file_out fungi_ITS_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_wsp_man.bsl -out fungi_ITS_species_wsp_man -title fungi_ITS_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_man.txt -seqid_title fungi_ITS_species_man -seqid_file_out fungi_ITS_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_man.bsl -out fungi_ITS_species_man -title fungi_ITS_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_wosp_man.txt -seqid_title fungi_ITS_species_wosp_man -seqid_file_out fungi_ITS_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_wosp_man.bsl -out fungi_ITS_species_wosp_man -title fungi_ITS_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/fungi_ITS_genus.txt blastdb/fungi_ITS_species_wsp.txt blastdb/fungi_ITS_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/fungi_ITS_genus.temp taxonomy fungi_ITS_genus.taxdb || exit $?
chmod 666 fungi_ITS_genus.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_wsp.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_wosp.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_genus_man.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_wsp_man.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_man.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_wosp_man.taxdb || exit $?
