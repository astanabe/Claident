if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
wget http://xrl.us/cpanm || exit $?
chmod 755 cpanm || exit $?
if test -w $PREFIX; then
mkdir -p $PREFIX/share/claident || exit $?
./cpanm -L $PREFIX/share/claident File::Copy::Recursive DBI DBD::SQLite Math::BaseCnv Math::CDF || exit $?
else
sudo -E mkdir -p $PREFIX/share/claident || exit $?
sudo -E ./cpanm -L $PREFIX/share/claident File::Copy::Recursive DBI DBD::SQLite Math::BaseCnv Math::CDF || exit $?
fi
perl -I$PREFIX/share/claident/lib/perl5 -e 'use File::Copy::Recursive;use DBD::SQLite;use Math::BaseCnv;use Math::CDF' || exit $?
rm -f cpanm || exit $?
