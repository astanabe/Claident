#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=131567 --excludetaxid=7742 taxonomy semiall_temp.taxdb || exit $?
# extract species-level identified sequences
clretrieveacc --includetaxa=genus,.+,species,.+ --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=semiall_temp.taxdb semiall_species.txt &
clretrieveacc --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=semiall_temp.taxdb semiall_genus.txt &
clretrieveacc --includetaxa=family,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=semiall_temp.taxdb semiall_family.txt &
clretrieveacc --includetaxa=order,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=semiall_temp.taxdb semiall_order.txt &
clretrieveacc --includetaxa=class,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=semiall_temp.taxdb semiall_class.txt &
wait
# del duplicate
clelimdupacc --workspace=disk semiall_species.txt semiall_genus.txt semiall_undergenus.txt &
clelimdupacc --workspace=disk semiall_species.txt semiall_genus.txt semiall_family.txt semiall_underfamily.txt &
clelimdupacc --workspace=disk semiall_species.txt semiall_genus.txt semiall_family.txt semiall_order.txt semiall_underorder.txt &
clelimdupacc --workspace=disk semiall_species.txt semiall_genus.txt semiall_family.txt semiall_order.txt semiall_class.txt semiall_underclass.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_underclass.txt ../semiall_underclass.txt semiall_underclass.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../semiall_underorder.txt semiall_underorder.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../semiall_underfamily.txt semiall_underfamily.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../semiall_undergenus.txt semiall_undergenus.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../semiall_species.txt semiall_species.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in semiall_underorder.txt -seqid_title semiall_order -seqid_file_out semiall_order.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist semiall_order.bsl -out semiall_order -title semiall_order" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in semiall_underfamily.txt -seqid_title semiall_family -seqid_file_out semiall_family.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist semiall_family.bsl -out semiall_family -title semiall_family" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in semiall_undergenus.txt -seqid_title semiall_genus -seqid_file_out semiall_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist semiall_genus.bsl -out semiall_genus -title semiall_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in semiall_species.txt -seqid_title semiall_species -seqid_file_out semiall_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist semiall_species.bsl -out semiall_species -title semiall_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_undergenus.txt -seqid_title prokaryota_all_genus -seqid_file_out prokaryota_all_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_genus.bsl -out prokaryota_all_genus -title prokaryota_all_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_all_species.txt -seqid_title prokaryota_all_species -seqid_file_out prokaryota_all_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_all_species.bsl -out prokaryota_all_species -title prokaryota_all_species" &
wait
cd .. || exit $?
# make taxdb
ln -s overall_class.taxdb semiall_class.taxdb || exit $?
ln -s overall_class.taxdb semiall_order.taxdb || exit $?
ln -s overall_class.taxdb semiall_family.taxdb || exit $?
ln -s overall_class.taxdb semiall_genus.taxdb || exit $?
ln -s overall_class.taxdb semiall_species.taxdb || exit $?
rm semiall_temp.taxdb || exit $?
