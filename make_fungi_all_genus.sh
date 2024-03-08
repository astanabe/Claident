#!/bin/sh
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --excluderefseq=enable --includetaxid=4751 taxonomy fungi.taxdb || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=fungi.taxdb fungi_all_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=fungi.taxdb fungi_all_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=fungi.taxdb fungi_all_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=fungi.taxdb fungi_all_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_genus.txt fungi_all_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_wsp.txt fungi_all_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species.txt fungi_all_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_wosp.txt fungi_all_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_genus_man.txt fungi_all_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_wsp_man.txt fungi_all_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_man.txt fungi_all_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_wosp_man.txt fungi_all_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_genus.txt -seqid_title fungi_all_genus -seqid_file_out fungi_all_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_genus.bsl -out fungi_all_genus -title fungi_all_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_wsp.txt -seqid_title fungi_all_species_wsp -seqid_file_out fungi_all_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_wsp.bsl -out fungi_all_species_wsp -title fungi_all_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species.txt -seqid_title fungi_all_species -seqid_file_out fungi_all_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species.bsl -out fungi_all_species -title fungi_all_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_wosp.txt -seqid_title fungi_all_species_wosp -seqid_file_out fungi_all_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_wosp.bsl -out fungi_all_species_wosp -title fungi_all_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_genus_man.txt -seqid_title fungi_all_genus_man -seqid_file_out fungi_all_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_genus_man.bsl -out fungi_all_genus_man -title fungi_all_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_wsp_man.txt -seqid_title fungi_all_species_wsp_man -seqid_file_out fungi_all_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_wsp_man.bsl -out fungi_all_species_wsp_man -title fungi_all_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_man.txt -seqid_title fungi_all_species_man -seqid_file_out fungi_all_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_man.bsl -out fungi_all_species_man -title fungi_all_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_wosp_man.txt -seqid_title fungi_all_species_wosp_man -seqid_file_out fungi_all_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_wosp_man.bsl -out fungi_all_species_wosp_man -title fungi_all_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/fungi_all_genus.txt blastdb/fungi_all_species_wsp.txt blastdb/fungi_all_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/fungi_all_genus.temp taxonomy fungi_all_genus.taxdb || exit $?
chmod 666 fungi_all_genus.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_wsp.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_wosp.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_genus_man.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_wsp_man.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_man.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_wosp_man.taxdb || exit $?
