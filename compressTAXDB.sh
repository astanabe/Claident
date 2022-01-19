#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
chmod 666 *.taxdb
ls *_*_genus.taxdb | grep -P -o '^[^_]+_[^_]+_' | xargs -L 1 -P 8 -I {} sh -c 'tar -c --use-compress-program="xz -T 1 -9e" -f {}genus.taxdb.tar.xz {}*.taxdb'
tar -c --use-compress-program="xz -T 0 -9e" -f overall_class.taxdb.tar.xz overall_*.taxdb
ls *.tar.xz | xargs -L 1 -P 16 -I {} sh -c 'sha256sum {} > {}.sha256'
