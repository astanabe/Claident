#!/bin/sh
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33090[Organism:exp] AND chloroplast[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' plants_cp.txt || exit $?
# make taxonomy database
clmaketaxdb --excluderefseq=enable --includetaxid=33090 taxonomy plants.taxdb || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_cp.txt --taxdb=plants.taxdb plants_cp_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_genus.txt plants_cp_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_species_wsp.txt plants_cp_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_species.txt plants_cp_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_species_wosp.txt plants_cp_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_genus_man.txt plants_cp_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_species_wsp_man.txt plants_cp_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_species_man.txt plants_cp_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_cp_species_wosp_man.txt plants_cp_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_genus.txt -seqid_title plants_cp_genus -seqid_file_out plants_cp_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_genus.bsl -out plants_cp_genus -title plants_cp_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_species_wsp.txt -seqid_title plants_cp_species_wsp -seqid_file_out plants_cp_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_species_wsp.bsl -out plants_cp_species_wsp -title plants_cp_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_species.txt -seqid_title plants_cp_species -seqid_file_out plants_cp_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_species.bsl -out plants_cp_species -title plants_cp_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_species_wosp.txt -seqid_title plants_cp_species_wosp -seqid_file_out plants_cp_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_species_wosp.bsl -out plants_cp_species_wosp -title plants_cp_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_genus_man.txt -seqid_title plants_cp_genus_man -seqid_file_out plants_cp_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_genus_man.bsl -out plants_cp_genus_man -title plants_cp_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_species_wsp_man.txt -seqid_title plants_cp_species_wsp_man -seqid_file_out plants_cp_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_species_wsp_man.bsl -out plants_cp_species_wsp_man -title plants_cp_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_species_man.txt -seqid_title plants_cp_species_man -seqid_file_out plants_cp_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_species_man.bsl -out plants_cp_species_man -title plants_cp_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_cp_species_wosp_man.txt -seqid_title plants_cp_species_wosp_man -seqid_file_out plants_cp_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_cp_species_wosp_man.bsl -out plants_cp_species_wosp_man -title plants_cp_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/plants_cp_genus.txt blastdb/plants_cp_species_wsp.txt blastdb/plants_cp_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/plants_cp_genus.temp taxonomy plants_cp_genus.taxdb || exit $?
chmod 666 plants_cp_genus.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_species_wsp.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_species.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_species_wosp.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_genus_man.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_species_wsp_man.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_species_man.taxdb || exit $?
ln -s plants_cp_genus.taxdb plants_cp_species_wosp_man.taxdb || exit $?
