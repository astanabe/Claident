#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=2,2157 taxonomy prokaryota.taxdb &
clmaketaxdb taxonomy overall_temp.taxdb &
wait
# extract xx-level identified sequences
clretrieveacc --excludetaxid=12908,28384 --maxrank=class --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_class.txt &
clretrieveacc --excludetaxid=12908,28384 --maxrank=order --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_order.txt &
clretrieveacc --excludetaxid=12908,28384 --maxrank=family --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_family.txt &
clretrieveacc --excludetaxid=12908,28384 --maxrank=genus --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_genus.txt &
clretrieveacc --excludetaxid=12908,28384 --maxrank=species --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_species_wsp.txt &
clretrieveacc --excludetaxid=12908,28384 --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=overall_temp.taxdb overall_species.txt &
clretrieveacc --excludetaxid=12908,28384 --maxrank=species --ngword='species, sp\.,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=overall_temp.taxdb overall_species_wosp.txt &
wait
clretrieveacc --maxrank=genus --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=prokaryota.taxdb prokaryota_all_genus.txt &
clretrieveacc --maxrank=species --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=prokaryota.taxdb prokaryota_all_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=prokaryota.taxdb prokaryota_all_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=prokaryota.taxdb prokaryota_all_species_wosp.txt &
wait
cd blastdb || exit $?
# make BLAST database
# NT-independent
clblastdbcmd --blastdb=./nt --output=FASTA --numthreads=16 --compress=gzip --filejoin=disable ../overall_class.txt temp_class || exit $?
clmakeblastdb --numthreads=16 "temp_class.*.gz" overall_class || exit $?
rm temp_class.*.gz || exit $?
clblastdbcmd --blastdb=./nt --output=ACCESSION --numthreads=16 ../overall_class.txt overall_class.txt || exit $?
clextractdupacc --workspace=disk overall_class.txt ../overall_order.txt overall_order.txt &
clextractdupacc --workspace=disk overall_class.txt ../overall_family.txt overall_family.txt &
clextractdupacc --workspace=disk overall_class.txt ../overall_genus.txt overall_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../overall_species_wsp.txt overall_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../overall_species.txt overall_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../overall_species_wosp.txt overall_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_all_genus.txt prokaryota_all_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_all_species_wsp.txt prokaryota_all_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_all_species.txt prokaryota_all_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_all_species_wosp.txt prokaryota_all_species_wosp.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_order.txt -seqid_title overall_order -seqid_file_out overall_order.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_order.bsl -out overall_order -title overall_order" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_family.txt -seqid_title overall_family -seqid_file_out overall_family.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_family.bsl -out overall_family -title overall_family" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_genus.txt -seqid_title overall_genus -seqid_file_out overall_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_genus.bsl -out overall_genus -title overall_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_species_wsp.txt -seqid_title overall_species_wsp -seqid_file_out overall_species_wsp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_species_wsp.bsl -out overall_species_wsp -title overall_species_wsp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_species.txt -seqid_title overall_species -seqid_file_out overall_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_species.bsl -out overall_species -title overall_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_species_wosp.txt -seqid_title overall_species_wosp -seqid_file_out overall_species_wosp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_species_wosp.bsl -out overall_species_wosp -title overall_species_wosp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_genus.txt -seqid_title prokaryota_all_genus -seqid_file_out prokaryota_all_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_genus.bsl -out prokaryota_all_genus -title prokaryota_all_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_species_wsp.txt -seqid_title prokaryota_all_species_wsp -seqid_file_out prokaryota_all_species_wsp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_species_wsp.bsl -out prokaryota_all_species_wsp -title prokaryota_all_species_wsp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_species.txt -seqid_title prokaryota_all_species -seqid_file_out prokaryota_all_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_species.bsl -out prokaryota_all_species -title prokaryota_all_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_species_wosp.txt -seqid_title prokaryota_all_species_wosp -seqid_file_out prokaryota_all_species_wosp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_species_wosp.bsl -out prokaryota_all_species_wosp -title prokaryota_all_species_wosp" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/prokaryota_all_genus.txt taxonomy prokaryota_all_genus.taxdb &
clmaketaxdb --workspace=disk --acclist=blastdb/overall_class.txt taxonomy overall_class.taxdb &
wait
ln -s overall_class.taxdb overall_order.taxdb || exit $?
ln -s overall_class.taxdb overall_family.taxdb || exit $?
ln -s overall_class.taxdb overall_genus.taxdb || exit $?
ln -s overall_class.taxdb overall_species_wsp.taxdb || exit $?
ln -s overall_class.taxdb overall_species.taxdb || exit $?
ln -s overall_class.taxdb overall_species_wosp.taxdb || exit $?
ln -s prokaryota_all_genus.taxdb prokaryota_all_species_wsp.taxdb || exit $?
ln -s prokaryota_all_genus.taxdb prokaryota_all_species.taxdb || exit $?
ln -s prokaryota_all_genus.taxdb prokaryota_all_species_wosp.taxdb || exit $?
rm overall_temp.taxdb || exit $?
