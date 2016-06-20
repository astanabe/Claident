# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/nt.??.tar.gz || exit $?
#wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/nt.??.tar.gz.md5 || exit $?
#md5sum -c nt.??.tar.gz.md5 || exit $?
#rm nt.??.tar.gz.md5 || exit $?
wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz || exit $?
#wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz.md5 || exit $?
#md5sum -c taxdb.tar.gz.md5 || exit $?
#rm taxdb.tar.gz.md5 || exit $?
for f in *.tar.gz; do tar -xzf $f || exit $?; done
chmod 644 *.tar.gz || exit $?
rm *.tar.gz || exit $?
cd .. || exit $?
