#!/bin/sh
# Set number of processor cores used for computation
export NCPU=`grep -c processor /proc/cpuinfo`
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
chmod 666 *.taxdb
ls *_*_genus.taxdb | grep -P -o '^[^_]+_[^_]+_' | xargs -P $(($NCPU / 8)) -I {} sh -c 'tar -c --use-compress-program="xz -T 8 -9e" -f {}genus.taxdb.tar.xz {}*.taxdb'
tar -c --use-compress-program="xz -T 0 -9e" -f overall_class.taxdb.tar.xz overall_*.taxdb
ls *.tar.xz | xargs -P $NCPU -I {} sh -c 'sha256sum {} > {}.sha256'
