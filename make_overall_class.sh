#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=2,2157 taxonomy prokaryota.taxdb &
clmaketaxdb taxonomy overall_temp.taxdb &
wait
# extract xx-level identified sequences
clretrieveacc --includetaxa=genus,.+,species,.+ --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=prokaryota.taxdb prokaryota_all_species.txt &
clretrieveacc --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=prokaryota.taxdb prokaryota_all_genus.txt &
clretrieveacc --excludetaxid=12908,28384 --includetaxa=genus,.+,species,.+ --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=overall_temp.taxdb overall_species.txt &
clretrieveacc --excludetaxid=12908,28384 --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_genus.txt &
clretrieveacc --excludetaxid=12908,28384 --includetaxa=family,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_family.txt &
clretrieveacc --excludetaxid=12908,28384 --includetaxa=order,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_order.txt &
clretrieveacc --excludetaxid=12908,28384 --includetaxa=class,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=overall_temp.taxdb overall_class.txt &
wait
# del duplicate
clelimdupacc --workspace=disk prokaryota_all_species.txt prokaryota_all_genus.txt prokaryota_all_undergenus.txt &
clelimdupacc --workspace=disk overall_species.txt overall_genus.txt overall_undergenus.txt &
clelimdupacc --workspace=disk overall_species.txt overall_genus.txt overall_family.txt overall_underfamily.txt &
clelimdupacc --workspace=disk overall_species.txt overall_genus.txt overall_family.txt overall_order.txt overall_underorder.txt &
clelimdupacc --workspace=disk overall_species.txt overall_genus.txt overall_family.txt overall_order.txt overall_class.txt overall_underclass.txt &
wait
cd blastdb || exit $?
# make BLAST database
# NT-independent
clblastdbcmd --blastdb=./nt --output=FASTA --numthreads=8 --compress=gzip --filejoin=disable ../overall_underclass.txt temp_class || exit $?
clmakeblastdb --numthreads=8 "temp_class.*.gz" overall_class || exit $?
rm temp_class.*.gz || exit $?
clblastdbcmd --blastdb=./nt --output=ACCESSION --numthreads=8 ../overall_underclass.txt overall_underclass.txt || exit $?
clextractdupacc --workspace=disk overall_underclass.txt ../overall_underorder.txt overall_underorder.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../overall_underfamily.txt overall_underfamily.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../overall_undergenus.txt overall_undergenus.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../overall_species.txt overall_species.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../prokaryota_all_undergenus.txt prokaryota_all_undergenus.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../prokaryota_all_species.txt prokaryota_all_species.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_underorder.txt -seqid_title overall_order -seqid_file_out overall_order.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_order.bsl -out overall_order -title overall_order" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_underfamily.txt -seqid_title overall_family -seqid_file_out overall_family.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_family.bsl -out overall_family -title overall_family" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_undergenus.txt -seqid_title overall_genus -seqid_file_out overall_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_genus.bsl -out overall_genus -title overall_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in overall_species.txt -seqid_title overall_species -seqid_file_out overall_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist overall_species.bsl -out overall_species -title overall_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_undergenus.txt -seqid_title prokaryota_all_genus -seqid_file_out prokaryota_all_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_genus.bsl -out prokaryota_all_genus -title prokaryota_all_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_species.txt -seqid_title prokaryota_all_species -seqid_file_out prokaryota_all_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_species.bsl -out prokaryota_all_species -title prokaryota_all_species" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/prokaryota_all_undergenus.txt taxonomy prokaryota_all_genus.taxdb &
clmaketaxdb --workspace=disk --acclist=blastdb/overall_underclass.txt taxonomy overall_class.taxdb &
wait
ln -s prokaryota_all_genus.taxdb prokaryota_all_species.taxdb || exit $?
ln -s overall_class.taxdb overall_order.taxdb || exit $?
ln -s overall_class.taxdb overall_family.taxdb || exit $?
ln -s overall_class.taxdb overall_genus.taxdb || exit $?
ln -s overall_class.taxdb overall_species.taxdb || exit $?
rm overall_temp.taxdb || exit $?
