#!/bin/bash
set -e

python3 -m http.server 8080 &

/usr/bin/livecd-creator --fslabel=1vyrain --cache=/var/cache/live --config=$1
/bin/cp *.iso /workspace/result/
