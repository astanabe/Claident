# get taxonomy database dump files from NCBI
mkdir -p taxonomy || exit $?
cd taxonomy || exit $?
wget -c ftp://ftp.ncbi.nih.gov/pub/taxonomy/gi_taxid_nucl.dmp.gz || exit $?
gzip -d gi_taxid_nucl.dmp.gz || exit $?
wget -c ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz || exit $?
tar -xzf taxdump.tar.gz || exit $?
chmod 644 taxdump.tar.gz || exit $?
rm taxdump.tar.gz || exit $?
cd .. || exit $?
