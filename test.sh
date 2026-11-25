#!/bin/sh
# Builds the image and exercises run-sync with stub mbsync/wget:
# stale-lock recovery, concurrent-run skip + alert, repeated-failure alert.
set -e
cd "$(dirname "$0")"
docker build -q -t imapsync-test . >/dev/null

docker run --rm --entrypoint sh imapsync-test -c '
set -e
mkdir -p /run/credentials /var/log/cron /stub
printf "PASSWORD=x\nTARGET=t\nEXCLUDE=\n" > /run/credentials/a@b.c
printf "APPRISE_URL=http://apprise/notify\nSKIP_ALERT_THRESHOLD=2\nFAIL_ALERT_THRESHOLD=2\n" > /run/sync-config
# stub wget records each alert; stub mbsync exits with $MB_RC
printf "#!/bin/sh\necho \"\$@\" >> /tmp/alerts\n" > /stub/wget
printf "#!/bin/sh\nexit \${MB_RC:-0}\n" > /stub/mbsync
chmod +x /stub/*; export PATH=/stub:$PATH

# 1. leftover lockfile from a killed run (nobody holds the flock) must not block
echo 5635 > /tmp/run-sync-a@b.c.lock
MB_RC=0 run-sync a@b.c >/dev/null
test ! -s /tmp/alerts || { echo "FAIL 1: unexpected alert"; exit 1; }

# 2. a live holder makes runs skip; alert fires once, at the threshold
flock /tmp/run-sync-a@b.c.lock sleep 5 & sleep 1
for i in 1 2 3; do run-sync a@b.c; done
test "$(grep -c STUCK /tmp/alerts)" = 1 || { echo "FAIL 2: expected one STUCK alert"; exit 1; }
wait

# 3. failing mbsync alerts once at the threshold, success resets the streak
: > /tmp/alerts
for i in 1 2 3; do MB_RC=1 run-sync a@b.c >/dev/null; done
test "$(grep -c FAILED /tmp/alerts)" = 1 || { echo "FAIL 3: expected one FAILED alert"; exit 1; }
MB_RC=0 run-sync a@b.c >/dev/null
test ! -e /tmp/run-sync-a@b.c.fails || { echo "FAIL 3b: streak not reset"; exit 1; }
echo ALL OK'
