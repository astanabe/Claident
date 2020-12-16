# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/nt.??.tar.gz || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/nt.??.tar.gz.md5 || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz.md5 || exit $?
ls *.md5 | xargs -L 1 -P 16 -I {} sh -c "md5sum -c {} || exit $?" || exit $?
rm *.md5 || exit $?
ls *.tar.gz | xargs -L 1 -P 16 -I {} sh -c "tar -xzf {} || exit $?" || exit $?
chmod 644 *.tar.gz || exit $?
rm *.tar.gz || exit $?
cd .. || exit $?
