sh -c "yes '' | cpan -fi DBI DBD::SQLite LWP File::Copy::Recursive" || exit $?
if test -z $PREFIX; then
export PREFIX=/usr/local || exit $?
fi
make PREFIX=$PREFIX || exit $?
make PREFIX=$PREFIX install || exit $?
make clean || exit $?
cp $PREFIX/share/claident/.claident ~/.claident || exit $?
cp $PREFIX/share/claident/.claident /etc/claident/.claident || exit $?
