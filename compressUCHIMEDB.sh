#!/bin/sh
t=`TZ=JST-9 date +%Y%m%d`
cd uchimedb
tar -c --use-compress-program="xz -T 0 -9e" -f cdu_$t.tar.xz cdu*.fasta
sha256sum cdu_$t.tar.xz > cdu_$t.tar.xz.sha256
cd ..
