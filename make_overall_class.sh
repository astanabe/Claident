#!/bin/sh
#$ -l nc=28
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb taxonomy overall_temp.taxdb || exit $?
# extract species-level identified sequences
clretrievegi --excludetaxid=12908,28384 --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --taxdb=overall_temp.taxdb overall_species.txt || exit $?
clretrievegi --excludetaxid=12908,28384 --includetaxa=genus,.+ --taxdb=overall_temp.taxdb overall_genus.txt || exit $?
clretrievegi --excludetaxid=12908,28384 --includetaxa=family,.+ --taxdb=overall_temp.taxdb overall_family.txt || exit $?
clretrievegi --excludetaxid=12908,28384 --includetaxa=order,.+ --taxdb=overall_temp.taxdb overall_order.txt || exit $?
clretrievegi --excludetaxid=12908,28384 --includetaxa=class,.+ --taxdb=overall_temp.taxdb overall_class.txt || exit $?
# del duplicate
clelimdupgi --workspace=disk overall_species.txt overall_genus.txt overall_undergenus.txt || exit $?
clelimdupgi --workspace=disk overall_undergenus.txt overall_family.txt overall_underfamily.txt || exit $?
clelimdupgi --workspace=disk overall_underfamily.txt overall_order.txt overall_underorder.txt || exit $?
clelimdupgi --workspace=disk overall_underorder.txt overall_class.txt overall_underclass.txt || exit $?
cd blastdb || exit $?
# shrink database
blastdbcmd -db ./nt -target_only -entry_batch ../overall_underclass.txt -out - 2> /dev/null | gzip -c > overall_temp.fasta.gz || exit $?
#clshrinkblastdb --taxdb=../overall_temp.taxdb --minlen=100 --maxlen=20000 --dellongseq=disable --numthreads=8 overall_temp.fasta.gz overall_temp2.fasta.gz || exit $?
#rm overall_temp.fasta.gz || exit $?
#clderepblastdb --minlen=100 --maxlen=200000 --dellongseq=enable --numthreads=8 overall_temp2.fasta.gz overall_class.fasta.gz || exit $?
#rm overall_temp2.fasta.gz || exit $?
clderepblastdb --minlen=100 --maxlen=200000 --dellongseq=enable --numthreads=28 overall_temp.fasta.gz overall_class.fasta.gz || exit $?
rm overall_temp.fasta.gz || exit $?
# make BLAST database
# NT-independent
gzip -dc overall_class.fasta.gz | makeblastdb -dbtype nucl -parse_seqids -hash_index -out overall_class -title overall_class || exit $?
rm overall_class.fasta.gz || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_underorder.txt -out overall_order -title overall_order 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_underfamily.txt -out overall_family -title overall_family 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_undergenus.txt -out overall_genus -title overall_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../overall_species.txt -out overall_species -title overall_species 2> /dev/null || exit $?
#
blastdbcmd -db ./overall_class -target_only -entry all -out ../overall_underclass.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --workspace=disk --gilist=overall_underclass.txt taxonomy overall_class.taxdb || exit $?
ln -s overall_class.taxdb overall_order.taxdb || exit $?
ln -s overall_class.taxdb overall_family.taxdb || exit $?
ln -s overall_class.taxdb overall_genus.taxdb || exit $?
ln -s overall_class.taxdb overall_species.taxdb || exit $?
rm overall_temp.taxdb || exit $?
