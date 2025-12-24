#!/bin/bash
set -euo pipefail
set -x

python3 -m http.server 8080 &
HTTP_PID=$!

# run creator
/usr/bin/livecd-creator --fslabel=1vyrain --cache=/var/cache/live --config="$1"

# stop http server
kill "$HTTP_PID" || true

# show what was produced and where
echo "Searching for ISO files under /workspace and /"
find /workspace -maxdepth 3 -type f -name "*.iso" -ls || true
find / -maxdepth 3 -type f -name "*.iso" -ls 2>/dev/null || true

echo "Current dir ISO listing:"
ls -lah *.iso || true

echo "Copying to /workspace/result"
mkdir -p /workspace/result
cp -v *.iso /workspace/result/

echo "Result dir:"
ls -lah /workspace/result
