# get nt database from NCBI
mkdir -p blastdb || exit $?
cd blastdb || exit $?
wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nt.gz || exit $?
#wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nt.gz.md5 || exit $?
#md5sum -c nt.gz.md5 || exit $?
#rm nt.gz.md5 || exit $?
gzip -dc nt.gz | makeblastdb -dbtype nucl -in - -parse_seqids -hash_index -out nt -title nt
rm nt.gz || exit $?
cd .. || exit $?
