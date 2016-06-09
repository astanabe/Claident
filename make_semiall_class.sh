#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# make taxonomy database
clmaketaxdb --includetaxid=131567 --excludetaxid=7742 taxonomy semiall_temp.taxdb || exit $?
# extract species-level identified sequences
clretrievegi --includetaxa=genus,.+ --maxrank=species --ngword=' sp\.' --taxdb=semiall_temp.taxdb semiall_species.txt || exit $?
clretrievegi --includetaxa=genus,.+ --taxdb=semiall_temp.taxdb semiall_genus.txt || exit $?
clretrievegi --includetaxa=family,.+ --taxdb=semiall_temp.taxdb semiall_family.txt || exit $?
clretrievegi --includetaxa=order,.+ --taxdb=semiall_temp.taxdb semiall_order.txt || exit $?
clretrievegi --includetaxa=class,.+ --taxdb=semiall_temp.taxdb semiall_class.txt || exit $?
# del duplicate
clelimdupgi --workspace=disk semiall_species.txt semiall_genus.txt semiall_undergenus.txt || exit $?
clelimdupgi --workspace=disk semiall_undergenus.txt semiall_family.txt semiall_underfamily.txt || exit $?
clelimdupgi --workspace=disk semiall_underfamily.txt semiall_order.txt semiall_underorder.txt || exit $?
clelimdupgi --workspace=disk semiall_underorder.txt semiall_class.txt semiall_underclass.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../semiall_underclass.txt -out semiall_class -title semiall_class 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../semiall_underorder.txt -out semiall_order -title semiall_order 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../semiall_underfamily.txt -out semiall_family -title semiall_family 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../semiall_undergenus.txt -out semiall_genus -title semiall_genus 2> /dev/null || exit $?
blastdb_aliastool -dbtype nucl -db ./overall_class -gilist ../semiall_species.txt -out semiall_species -title semiall_species 2> /dev/null || exit $?
#
blastdbcmd -db ./semiall_class -target_only -entry all -out ../semiall_underclass.txt -outfmt %g || exit $?
cd .. || exit $?
# minimize taxdb
clmaketaxdb --workspace=disk --gilist=semiall_underclass.txt taxonomy semiall_class.taxdb || exit $?
ln -s semiall_class.taxdb semiall_order.taxdb || exit $?
ln -s semiall_class.taxdb semiall_family.taxdb || exit $?
ln -s semiall_class.taxdb semiall_genus.taxdb || exit $?
ln -s semiall_class.taxdb semiall_species.taxdb || exit $?
rm semiall_temp.taxdb || exit $?
