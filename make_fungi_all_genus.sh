#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=4751 taxonomy fungi.taxdb || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --additional=enable --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=fungi.taxdb fungi_all_species_wosp.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_genus.txt fungi_all_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_wsp.txt fungi_all_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species.txt fungi_all_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_all_species_wosp.txt fungi_all_species_wosp.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_genus.txt -seqid_title fungi_all_genus -seqid_file_out fungi_all_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_genus.bsl -out fungi_all_genus -title fungi_all_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_wsp.txt -seqid_title fungi_all_species_wsp -seqid_file_out fungi_all_species_wsp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_wsp.bsl -out fungi_all_species_wsp -title fungi_all_species_wsp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species.txt -seqid_title fungi_all_species -seqid_file_out fungi_all_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species.bsl -out fungi_all_species -title fungi_all_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_all_species_wosp.txt -seqid_title fungi_all_species_wosp -seqid_file_out fungi_all_species_wosp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_all_species_wosp.bsl -out fungi_all_species_wosp -title fungi_all_species_wosp" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/fungi_all_genus.txt blastdb/fungi_all_species_wsp.txt blastdb/fungi_all_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/fungi_all_genus.temp taxonomy fungi_all_genus.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_wsp.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species.taxdb || exit $?
ln -s fungi_all_genus.taxdb fungi_all_species_wosp.taxdb || exit $?
