#!/bin/sh
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND mitochondrion[Filter] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' animals_mt.txt || exit $?
# make taxonomy database
clmaketaxdb --excluderefseq=enable --includetaxid=33208 taxonomy animals.taxdb || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_genus.txt animals_mt_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_species_wsp.txt animals_mt_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_species.txt animals_mt_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_species_wosp.txt animals_mt_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_genus_man.txt animals_mt_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_species_wsp_man.txt animals_mt_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_species_man.txt animals_mt_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../animals_mt_species_wosp_man.txt animals_mt_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_genus.txt -seqid_title animals_mt_genus -seqid_file_out animals_mt_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_genus.bsl -out animals_mt_genus -title animals_mt_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species_wsp.txt -seqid_title animals_mt_species_wsp -seqid_file_out animals_mt_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species_wsp.bsl -out animals_mt_species_wsp -title animals_mt_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species.txt -seqid_title animals_mt_species -seqid_file_out animals_mt_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species.bsl -out animals_mt_species -title animals_mt_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species_wosp.txt -seqid_title animals_mt_species_wosp -seqid_file_out animals_mt_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species_wosp.bsl -out animals_mt_species_wosp -title animals_mt_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_genus_man.txt -seqid_title animals_mt_genus_man -seqid_file_out animals_mt_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_genus_man.bsl -out animals_mt_genus_man -title animals_mt_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species_wsp_man.txt -seqid_title animals_mt_species_wsp_man -seqid_file_out animals_mt_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species_wsp_man.bsl -out animals_mt_species_wsp_man -title animals_mt_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species_man.txt -seqid_title animals_mt_species_man -seqid_file_out animals_mt_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species_man.bsl -out animals_mt_species_man -title animals_mt_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species_wosp_man.txt -seqid_title animals_mt_species_wosp_man -seqid_file_out animals_mt_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species_wosp_man.bsl -out animals_mt_species_wosp_man -title animals_mt_species_wosp_man" &
wait
cd .. || exit $?
# make taxdb
clelimdupacc blastdb/animals_mt_genus.txt blastdb/animals_mt_species_wsp.txt blastdb/animals_mt_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/animals_mt_genus.temp taxonomy animals_mt_genus.taxdb || exit $?
chmod 666 animals_mt_genus.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species_wsp.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species_wosp.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_genus_man.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species_wsp_man.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species_man.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species_wosp_man.taxdb || exit $?
#rm animals.taxdb || exit $?
#rm blastdb/animals_genus.* || exit $?
