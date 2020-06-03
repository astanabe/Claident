# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/v4/nt_v4.??.tar.gz || exit $?
#wget -c ftp://ftp.ncbi.nih.gov/blast/db/v4/nt_v4.??.tar.gz.md5 || exit $?
wget -c ftp://ftp.ncbi.nih.gov/blast/db/v4/taxdb.tar.gz || exit $?
#wget -c ftp://ftp.ncbi.nih.gov/blast/db/v4/taxdb.tar.gz.md5 || exit $?
#for f in *.md5; do perl -i -npe 's/nt\./nt_v4./' $f; md5sum -c $f; done
#rm *.md5 || exit $?
ls *.tar.gz | xargs -L 1 -P 4 tar -xzf || exit $?
chmod 644 *.tar.gz || exit $?
rm *.tar.gz || exit $?
cd .. || exit $?
