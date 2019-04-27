#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
t=`TZ=JST-9 date +%Y%m%d`
tar -c --use-compress-program="pixz -9" -f cdu_$t.tar.xz cdu*.fasta
sha256sum cdu_$t.tar.xz > cdu_$t.tar.xz.sha256
