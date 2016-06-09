#!/bin/sh
#$ -l nc=14
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=2,2157 taxonomy prokaryota.taxdb || exit $?
# extract genus-level identified sequences
clretrievegi --includetaxa=genus,.+ --taxdb=prokaryota.taxdb prokaryota_all_genus.txt || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --taxdb=prokaryota.taxdb prokaryota_all_species.txt || exit $?
# del duplicate
clelimdupgi --workspace=disk prokaryota_all_species.txt prokaryota_all_genus.txt prokaryota_all_undergenus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent
blastdbcmd -db ./nt -target_only -entry_batch ../prokaryota_all_undergenus.txt -out - 2> /dev/null | gzip -c > prokaryota_all_temp.fasta.gz || exit $?
clderepblastdb --minlen=100 --maxlen=200000 --dellongseq=disable --numthreads=14 prokaryota_all_temp.fasta.gz prokaryota_all_genus.fasta.gz || exit $?
rm prokaryota_all_temp.fasta.gz || exit $?
gzip -dc prokaryota_all_genus.fasta.gz | makeblastdb -dbtype nucl -parse_seqids -hash_index -out prokaryota_all_genus -title prokaryota_all_genus || exit $?
rm prokaryota_all_genus.fasta.gz || exit $?
blastdb_aliastool -dbtype nucl -db ./prokaryota_all_genus -gilist ../prokaryota_all_species.txt -out prokaryota_all_species -title prokaryota_all_species 2> /dev/null || exit $?
#
blastdbcmd -db ./prokaryota_all_genus -target_only -entry all -out ../prokaryota_all_genus.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --gilist=prokaryota_all_genus.txt taxonomy prokaryota_all_genus.taxdb || exit $?
ln -s prokaryota_all_genus.taxdb prokaryota_all_species.taxdb || exit $?
#rm prokaryota.taxdb || exit $?
