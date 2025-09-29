# Set number of processor cores used for computation
export NCPU=`grep -c processor /proc/cpuinfo`
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
aria2c https://ftp.ncbi.nih.gov/blast/db/ -o index.html || exit $?
grep -o -P '"nt.\d+.tar.gz.md5"' index.html | sort -u | perl -npe 's/"//g;s/^/https:\/\/ftp.ncbi.nih.gov\/blast\/db\//' > md5list.txt || exit $?
aria2c -c -i md5list.txt -j 3 -x 1 || exit $?
rm md5list.txt || exit $?
grep -o -P '"nt.\d+.tar.gz"' index.html | sort -u | perl -npe 's/"//g;s/^/https:\/\/ftp.ncbi.nih.gov\/blast\/db\//' > targzlist.txt || exit $?
aria2c -c -i targzlist.txt -j 3 -x 1 || exit $?
rm targzlist.txt || exit $?
rm index.html || exit $?
aria2c -c https://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz.md5 || exit $?
aria2c -c https://ftp.ncbi.nih.gov/blast/db/taxdb.tar.gz || exit $?
ls *.md5 | xargs -P $NCPU -I {} sh -c "md5sum -c {} || exit $?" || exit $?
rm *.md5 || exit $?
ls *.tar.gz | xargs -P $NCPU -I {} sh -c "tar -xzf {} || exit $?" || exit $?
chmod 644 *.tar.gz || sudo chmod 644 *.tar.gz || exit $?
rm -f *.tar.gz || sudo rm -f *.tar.gz || exit $?
cd .. || exit $?
