sudo yum install -y make perl-DBI perl-DBD-SQLite perl-libwww-perl perl-File-Copy-Recursive perl-CPAN perl-YAML tar gzip xz || exit $?
if test -z $PREFIX; then
export PREFIX=/usr/local || exit $?
fi
make PREFIX=$PREFIX || exit $?
make PREFIX=$PREFIX install || sudo make PREFIX=$PREFIX install || exit $?
make clean || exit $?
cp $PREFIX/share/claident/.claident ~/.claident || exit $?
#sudo mkdir /etc/claident/.claident || exit $?
#sudo cp $PREFIX/share/claident/.claident /etc/claident/.claident || exit $?
