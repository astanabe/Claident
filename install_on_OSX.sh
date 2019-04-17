sudo -E port install p5-dbi p5-dbd-sqlite p5-file-copy-recursive p5-libwww-perl gmake gnutar xz p5-io-compress build_arch=x86_64 || exit $?
sudo -HE sh -c "yes '' | cpan -fi IO::Compress::Lzma" || exit $?
if test -z $PREFIX; then
export PREFIX=/usr/local || exit $?
fi
gmake PREFIX=$PREFIX || exit $?
gmake PREFIX=$PREFIX install || sudo gmake PREFIX=$PREFIX install || exit $?
gmake clean || exit $?
cp $PREFIX/share/claident/.claident ~/.claident || exit $?
#sudo mkdir /etc/claident/.claident || exit $?
#sudo cp $PREFIX/share/claident/.claident /etc/claident/.claident || exit $?
