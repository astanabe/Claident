#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
ls *_*_genus.taxdb | grep -P -o '^[^_]+_[^_]+_' | xargs -L 1 -P 1 -I {} sh -c 'tar -c --use-compress-program="pixz -9" -f {}genus.taxdb.tar.xz {}*.taxdb'
ls *_class.taxdb | grep -P -o '^[^_]+_' | xargs -L 1 -P 1 -I {} sh -c 'tar -c --use-compress-program="pixz -9" -f {}class.taxdb.tar.xz {}*.taxdb'
ls *.tar.xz | xargs -L 1 -P 8 -I {} sh -c 'sha256sum {} > {}.sha256'
