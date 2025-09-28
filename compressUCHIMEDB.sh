#!/bin/sh
# Set date
if test -z ${date}; then
date=`TZ=JST-9 date +%Y.%m.%d` || exit $?
fi
# Compress UCHIME DBs
cd uchimedb
tar -c --use-compress-program="xz -T 0 -9e" -f ../uchimedb-v0.1.${date}.tar.xz cdu*.fasta
cd ..
sha256sum uchimedb-v0.1.${date}.tar.xz > uchimedb-v0.1.${date}.tar.xz.sha256
