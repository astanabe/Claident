#!/bin/sh
#$ -l nc=8
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=2,2157 taxonomy prokaryota.taxdb &
clmaketaxdb taxonomy overall_temp.taxdb &
wait
# extract xx-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --taxdb=prokaryota.taxdb prokaryota_all_species.txt &
clretrievegi --includetaxa=genus,.+ --taxdb=prokaryota.taxdb prokaryota_all_genus.txt &
clretrievegi --excludetaxid=12908,28384 --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --taxdb=overall_temp.taxdb overall_species.txt &
clretrievegi --excludetaxid=12908,28384 --includetaxa=genus,.+ --taxdb=overall_temp.taxdb overall_genus.txt &
clretrievegi --excludetaxid=12908,28384 --includetaxa=family,.+ --taxdb=overall_temp.taxdb overall_family.txt &
clretrievegi --excludetaxid=12908,28384 --includetaxa=order,.+ --taxdb=overall_temp.taxdb overall_order.txt &
clretrievegi --excludetaxid=12908,28384 --includetaxa=class,.+ --taxdb=overall_temp.taxdb overall_class.txt &
wait
# del duplicate
clelimdupgi --workspace=disk prokaryota_all_species.txt prokaryota_all_genus.txt prokaryota_all_undergenus.txt &
clelimdupgi --workspace=disk overall_species.txt overall_genus.txt overall_undergenus.txt || exit $?
wait
clelimdupgi --workspace=disk overall_undergenus.txt overall_family.txt overall_underfamily.txt || exit $?
clelimdupgi --workspace=disk overall_underfamily.txt overall_order.txt overall_underorder.txt || exit $?
clelimdupgi --workspace=disk overall_underorder.txt overall_class.txt overall_underclass.txt || exit $?
cd blastdb || exit $?
# make BLAST database
# NT-independent
clblastdbcmd --blastdb=./nt --output=FASTA --numthreads=8 ../overall_underclass.txt overall_class.fasta.gz || exit $?
gzip -dc overall_class.fasta.gz | makeblastdb -dbtype nucl -input_type fasta -hash_index -parse_seqids -max_file_sz 2G -in - -out overall_class -title overall_class || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../prokaryota_all_undergenus.txt -out prokaryota_all_genus -title prokaryota_all_genus &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../prokaryota_all_species.txt -out prokaryota_all_species -title prokaryota_all_species &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_underorder.txt -out overall_order -title overall_order &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_underfamily.txt -out overall_family -title overall_family &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_undergenus.txt -out overall_genus -title overall_genus &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_species.txt -out overall_species -title overall_species &
wait
#
clblastdbcmd --blastdb=./prokaryota_all_genus --output=GI --numthreads=8 ../prokaryota_all_undergenus.txt prokaryota_all_undergenus.txt || exit $?
clblastdbcmd --blastdb=./overall_class --output=GI --numthreads=8 ../overall_underclass.txt overall_underclass.txt || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=blastdb/prokaryota_all_undergenus.txt taxonomy prokaryota_all_genus.taxdb &
clmaketaxdb --workspace=disk --gilist=blastdb/overall_underclass.txt taxonomy overall_class.taxdb &
wait
ln -s prokaryota_all_genus.taxdb prokaryota_all_species.taxdb || exit $?
ln -s overall_class.taxdb overall_order.taxdb || exit $?
ln -s overall_class.taxdb overall_family.taxdb || exit $?
ln -s overall_class.taxdb overall_genus.taxdb || exit $?
ln -s overall_class.taxdb overall_species.taxdb || exit $?
rm overall_temp.taxdb || exit $?
