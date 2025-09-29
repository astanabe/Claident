# get taxonomy database dump files from NCBI
mkdir -p taxonomy || exit $?
cd taxonomy || exit $?
aria2c -c https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz.md5 || exit $?
aria2c -c https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz || exit $?
md5sum -c taxdump.tar.gz.md5 || exit $?
rm taxdump.tar.gz.md5 || exit $?
tar -xzf taxdump.tar.gz || exit $?
chmod 644 taxdump.tar.gz || sudo chmod 644 taxdump.tar.gz || exit $?
rm taxdump.tar.gz || sudo rm taxdump.tar.gz || exit $?
cd .. || exit $?
