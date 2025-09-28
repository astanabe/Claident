#!/bin/sh
# Set date
if test -z ${date}; then
date=`TZ=JST-9 date +%Y.%m.%d` || exit $?
fi
# Compress UCHIME DBs
cd uchimedb
tar -c --use-compress-program="xz -T 0 -9e" -f ../uchimedb-0.9.${date}.tar.xz cdu*.fasta
cd ..
sha256sum uchimedb-0.9.${date}.tar.xz > uchimedb-0.9.${date}.tar.xz.sha256
