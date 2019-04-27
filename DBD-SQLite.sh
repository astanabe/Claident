wget -c http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/DBD-SQLite-1.35.tar.gz || exit $?
tar -xzf DBD-SQLite-1.35.tar.gz || exit $?
cd DBD-SQLite-1.35 || exit $?
perl -i -npe 's/SQLITE_MAX_LENGTH 1000000000/SQLITE_MAX_LENGTH 2147483647/' sqlite3.c || exit $?
perl Makefile.PL || exit $?
make || exit $?
sudo make install || exit $?
cd .. || exit $?
rm -rf DBD-SQLite-1.35 || exit $?
