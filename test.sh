#!/bin/sh
# Builds the image and exercises entrypoint + run-sync with stub mbsync/wget/su-exec:
# stale-lock recovery, concurrent-run skip + alert, repeated-failure alert,
# awkward passwords surviving the credentials file and mbsync config, and an
# unreadable credentials file raising an alert.
set -e
cd "$(dirname "$0")"
docker build -q -t imapsync-test . >/dev/null

docker run --rm -i --entrypoint sh imapsync-test -s <<'INNER'
set -e
mkdir -p /run/credentials /var/log/cron /stub
printf "PASSWORD='x'\nTARGET='t'\nEXCLUDE=''\n" > /run/credentials/a@b.c
printf "APPRISE_URL='http://apprise/notify'\nSKIP_ALERT_THRESHOLD=2\nFAIL_ALERT_THRESHOLD=2\n" > /run/sync-config
# stub wget records each alert; stub mbsync keeps its config and exits with $MB_RC;
# stub su-exec lets entrypoint.sh finish instead of starting crond
printf '#!/bin/sh\necho "$@" >> /tmp/alerts\n' > /stub/wget
printf '#!/bin/sh\ncp "$2" /tmp/rc.out\nexit ${MB_RC:-0}\n' > /stub/mbsync
printf '#!/bin/sh\nexit 0\n' > /stub/su-exec
chmod +x /stub/*; export PATH=/stub:$PATH

# 1. leftover lockfile from a killed run (nobody holds the flock) must not block
echo 5635 > /tmp/run-sync-a@b.c.lock
MB_RC=0 run-sync a@b.c >/dev/null
test ! -s /tmp/alerts || { echo "FAIL 1: unexpected alert"; exit 1; }

# 2. a live holder makes runs skip; alerts fire on every skip from the threshold on
flock /tmp/run-sync-a@b.c.lock sleep 5 & sleep 1
for i in 1 2 3; do run-sync a@b.c; done
test "$(grep -c STUCK /tmp/alerts)" = 2 || { echo "FAIL 2: expected STUCK alerts on skips 2 and 3"; exit 1; }
wait

# 3. failing mbsync alerts on every failure from the threshold on, success resets the streak
: > /tmp/alerts
for i in 1 2 3; do MB_RC=1 run-sync a@b.c >/dev/null; done
test "$(grep -c FAILED /tmp/alerts)" = 2 || { echo "FAIL 3: expected FAILED alerts on failures 2 and 3"; exit 1; }
MB_RC=0 run-sync a@b.c >/dev/null
test ! -e /tmp/run-sync-a@b.c.fails || { echo "FAIL 3b: streak not reset"; exit 1; }

# 4. a password with spaces, quotes, backslash, parentheses, & ; $ goes through
#    entrypoint.sh -> credentials file -> run-sync -> mbsync config unchanged
PW=$(printf '%s' 'ab cd'\''ef"g\h(i)&;$j')
ACCOUNT_1="a@b.c|$PW|tgt|0 * * * *" /entrypoint.sh
run-sync a@b.c >/dev/null
cat > /tmp/expect <<'E'
Pass "ab cd'ef\"g\\h(i)&;$j"
E
grep -qxFf /tmp/expect /tmp/rc.out || { echo "FAIL 4: password mangled"; grep '^Pass' /tmp/rc.out | sed 's/Pass .*/Pass <redacted>/'; exit 1; }

# 5. an unreadable credentials file alerts instead of failing silently
printf "APPRISE_URL='http://apprise/notify'\nSKIP_ALERT_THRESHOLD=2\nFAIL_ALERT_THRESHOLD=1\n" > /run/sync-config
printf "PASSWORD=ab (cd\nTARGET=t\n" > /run/credentials/a@b.c
rm -f /tmp/run-sync-a@b.c.fails; : > /tmp/alerts
run-sync a@b.c >/dev/null 2>&1 || true
test "$(grep -c FAILED /tmp/alerts)" = 1 || { echo "FAIL 5: expected one FAILED alert"; exit 1; }
echo ALL OK
INNER
