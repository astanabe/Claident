# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
wget -c -e robots=off -r -l1 -np https://ftp.ncbi.nih.gov/blast/db/ -A nt.??.tar.gz.md5 -R env_nt.??.tar.gz.md5 || exit $?
wget -c -e robots=off -r -l1 -np https://ftp.ncbi.nih.gov/blast/db/ -A nt.??.tar.gz -R env_nt.??.tar.gz || exit $?
wget -c https://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz.md5 || exit $?
wget -c https://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz || exit $?
find ftp.ncbi.nih.gov -name nt.??.tar.gz | xargs -I {} mv {} ./
find ftp.ncbi.nih.gov -name nt.??.tar.gz.md5 | xargs -I {} mv {} ./
rm -rf ftp.ncbi.nih.gov || exit $?
ls *.md5 | xargs -L 1 -P 16 -I {} sh -c "md5sum -c {} || exit $?" || exit $?
rm *.md5 || exit $?
ls *.tar.gz | xargs -L 1 -P 16 -I {} sh -c "tar -xzf {} || exit $?" || exit $?
chmod 644 *.tar.gz || exit $?
rm *.tar.gz || exit $?
cd .. || exit $?
