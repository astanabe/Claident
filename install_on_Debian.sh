sudo apt-get install make libdbi-perl libdbd-sqlite3-perl libwww-perl tar xz-utils || exit $?
if test -z $PREFIX; then
export PREFIX=/usr/local || exit $?
fi
make PREFIX=$PREFIX || exit $?
make PREFIX=$PREFIX install || sudo make PREFIX=$PREFIX install || exit $?
make clean || exit $?
cp $PREFIX/share/claident/.claident ~/.claident || exit $?
sudo cp $PREFIX/share/claident/.claident /etc/claident/.claident || exit $?