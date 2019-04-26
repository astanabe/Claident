#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
cd blastdb
ls overall_class.??.nsq | grep -o -P '^.+\.' | xargs -L 1 -P 1 -I {} sh -c 'tar -c --use-compress-program="pixz -9" -f {}tar.xz {}n??'
ls *_*_genus.nal | grep -o -P '^[^_]+_[^_]+_' | xargs -L 1 -P 1 -I {} sh -c 'tar -c --use-compress-program="pixz -9" -f {}genus.tar.xz {}*.n.gil {}*.nal'
tar -c --use-compress-program="pixz -9" -f overall_class.tar.xz overall_*.n.gil overall_*.nal
tar -c --use-compress-program="pixz -9" -f semiall_class.tar.xz semiall_*.n.gil semiall_*.nal
ls *.tar.xz | xargs -L 1 -P 8 -I {} sh -c 'sha256sum {} > {}.sha256'
cd ..
