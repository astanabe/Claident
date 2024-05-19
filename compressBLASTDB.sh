#!/bin/sh
# Set number of processor cores used for computation
export NCPU=`grep -c processor /proc/cpuinfo`
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
cd blastdb
ls overall_class.*.nsq | grep -o -P '^.+\.' | xargs -P $(($NCPU / 8)) -I {} sh -c 'tar -c --use-compress-program="xz -T 8 -9e" -f {}tar.xz {}n*'
ls *_*_genus.nal | grep -o -P '^[^_]+_[^_]+_' | xargs -P $(($NCPU / 8)) -I {} sh -c 'tar -c --use-compress-program="xz -T 8 -9e" -f {}genus.tar.xz {}*.bsl {}*.nal'
tar -c --use-compress-program="xz -T 0 -9e" -f overall_class.tar.xz overall_*.bsl overall_*.nal
ls *.tar.xz | xargs -P $NCPU -I {} sh -c 'sha256sum {} > {}.sha256'
cd ..
