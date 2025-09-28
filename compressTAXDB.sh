#!/bin/sh
# Set number of processor cores used for computation
export NCPU=`grep -c processor /proc/cpuinfo`
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set date
if test -z ${date}; then
date=`TZ=JST-9 date +%Y.%m.%d` || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# Compress Taxonomy DB
chmod 666 *.taxdb
tar -c --use-compress-program="xz -T 0 -9e" -f taxdb-v0.1.${date}.tar.xz *_*_genus.taxdb overall_*.taxdb
sha256sum taxdb-v0.1.${date}.tar.xz > taxdb-v0.1.${date}.tar.xz.sha256
