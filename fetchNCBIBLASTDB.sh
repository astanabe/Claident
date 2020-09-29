# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/nt.??.tar.gz || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/nt.??.tar.gz.md5 || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz.md5 || exit $?
for f in *.md5; do md5sum -c $f; done
rm *.md5 || exit $?
ls *.tar.gz | xargs -L 1 -P 8 tar -xzf || exit $?
chmod 644 *.tar.gz || exit $?
rm *.tar.gz || exit $?
cd .. || exit $?
