sh -c "yes '' | cpan -fi DBI DBD::SQLite LWP File::Copy::Recursive IO::Compress::Lzma" || exit $?
if test -z $PREFIX; then
export PREFIX=/usr/local || exit $?
fi
make PREFIX=$PREFIX || exit $?
make PREFIX=$PREFIX install || exit $?
make clean || exit $?
echo "CLAIDENTHOME=$PREFIX/share/claident" > $PREFIX/share/claident/.claident || exit $?
echo "TAXONOMYDB=$PREFIX/share/claident/taxdb" >> $PREFIX/share/claident/.claident || exit $?
echo "BLASTDB="`cygpath -w "$PREFIX/share/claident/blastdb"` >> $PREFIX/share/claident/.claident || exit $?
echo "UCHIMEDB=$PREFIX/share/claident/uchimedb" >> $PREFIX/share/claident/.claident || exit $?
cp $PREFIX/share/claident/.claident ~/.claident || exit $?
