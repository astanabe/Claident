# get taxonomy database dump files from NCBI
mkdir -p taxonomy || exit $?
cd taxonomy || exit $?
/usr/local/share/claident/bin/blastdbcmd -db ../blastdb/nt -dbtype nucl -entry all -out acc_taxid.dmp -outfmt "%a %T" || exit $?
wget -c ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz || exit $?
tar -xzf taxdump.tar.gz || exit $?
chmod 644 taxdump.tar.gz || exit $?
rm taxdump.tar.gz || exit $?
cd .. || exit $?
