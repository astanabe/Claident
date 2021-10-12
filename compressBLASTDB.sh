#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
cd blastdb
ls overall_class.??.nsq | grep -o -P '^.+\.' | xargs -L 1 -P 1 -I {} sh -c 'tar -c --use-compress-program="xz -T 0 -9e" -f {}tar.xz {}n??'
ls *_*_genus.nal | grep -o -P '^[^_]+_[^_]+_' | xargs -L 1 -P 8 -I {} sh -c 'tar -c --use-compress-program="xz -T 1 -9e" -f {}genus.tar.xz {}*.bsl {}*.nal'
tar -c --use-compress-program="xz -T 0 -9e" -f overall_class.tar.xz overall_*.bsl overall_*.nal
ls *.tar.xz | xargs -L 1 -P 16 -I {} sh -c 'sha256sum {} > {}.sha256'
cd ..
