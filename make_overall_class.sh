#!/bin/sh
#$ -l nc=28
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
clelimdupgi --workspace=disk overall_undergenus.txt overall_family.txt overall_underfamily.txt || exit $?
clelimdupgi --workspace=disk overall_underfamily.txt overall_order.txt overall_underorder.txt || exit $?
clelimdupgi --workspace=disk overall_underorder.txt overall_class.txt overall_underclass.txt || exit $?
wait
cd blastdb || exit $?
# shrink database
blastdbcmd -db ./nt -target_only -entry_batch ../prokaryota_all_undergenus.txt -outfmt '%g %l' -out - 2> /dev/null | perl -ne 'if(/^(\d+)\s+(\d+)/&&$2>200000){print("$1\n");}' | blastdbcmd -db ./nt -target_only -entry_batch - -out - 2> /dev/null | gzip -c > prokaryota_long_temp.fasta.gz &
blastdbcmd -db ./nt -target_only -entry_batch ../overall_underclass.txt -out - 2> /dev/null | gzip -c > overall_temp.fasta.gz &
wait
clderepblastdb --minlen=100 --maxlen=200000 --dellongseq=enable --numthreads=28 overall_temp.fasta.gz overall_class.fasta.gz || exit $?
rm overall_temp.fasta.gz || exit $?
# make BLAST database
# NT-independent
gzip -dc overall_class.fasta.gz prokaryota_long_temp.fasta.gz | makeblastdb -dbtype nucl -parse_seqids -hash_index -out overall_class -title overall_class || exit $?
rm overall_class.fasta.gz prokaryota_long_temp.fasta.gz || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../prokaryota_all_undergenus.txt -out prokaryota_all_genus -title prokaryota_all_genus &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../prokaryota_all_species.txt -out prokaryota_all_species -title prokaryota_all_species &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_underorder.txt -out overall_order -title overall_order &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_underfamily.txt -out overall_family -title overall_family &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_undergenus.txt -out overall_genus -title overall_genus &
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_species.txt -out overall_species -title overall_species &
wait
#
blastdbcmd -db ./prokaryota_all_genus -target_only -entry all -out ../prokaryota_all_undergenus.txt -outfmt '%g' &
blastdbcmd -db ./overall_class -target_only -entry all -out ../overall_underclass.txt -outfmt '%g' &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=prokaryota_all_undergenus.txt taxonomy prokaryota_all_genus.taxdb &
clmaketaxdb --workspace=disk --gilist=overall_underclass.txt taxonomy overall_class.taxdb &
wait
ln -s prokaryota_all_genus.taxdb prokaryota_all_species.taxdb || exit $?
ln -s overall_class.taxdb overall_order.taxdb || exit $?
ln -s overall_class.taxdb overall_family.taxdb || exit $?
ln -s overall_class.taxdb overall_genus.taxdb || exit $?
ln -s overall_class.taxdb overall_species.taxdb || exit $?
rm overall_temp.taxdb || exit $?
