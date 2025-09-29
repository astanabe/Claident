# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# get taxonomy database dump files from NCBI
mkdir -p taxonomy || exit $?
cd taxonomy || exit $?
$PREFIX/share/claident/bin/blastdbcmd -db ../blastdb/nt -dbtype nucl -entry all -outfmt "%a %T" -out acc_taxid.dmp || exit $?
cd .. || exit $?
