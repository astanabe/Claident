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
# Compress BLAST DBs
cd blastdb
ls overall_class.*.nsq | grep -o -P '^.+\.' | xargs -P $(($NCPU / 4)) -I {} sh -c 'tar -c --use-compress-program="xz -T 4 -9e" -f ../{}blastdb-0.9.${date}.tar.xz {}n*'
tar -c --use-compress-program="xz -T 0 -9e" -f ../blastdb-0.9.${date}.tar.xz *_*_genus.bsl *_*_genus.nal overall_*.bsl overall_*.nal
cd ..
ls blastdb-0.9.${date}.tar.xz *.blastdb-0.9.${date}.tar.xz | xargs -P $NCPU -I {} sh -c 'sha256sum {} > {}.sha256'
for f in `ls *.blastdb-0.9.${date}.tar.xz.sha256`; do cat $f >> blastdb-0.9.${date}.tar.xz.sha256; rm $f; done
