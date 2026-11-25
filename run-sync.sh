#!/bin/sh

ACCOUNT="$1"
CRED_FILE="/run/credentials/$ACCOUNT"
LOGFILE="/var/log/cron/${ACCOUNT}.log"
LOCKFILE="/tmp/run-sync-${ACCOUNT}.lock"
SKIPFILE="/tmp/run-sync-${ACCOUNT}.skips"
FAILFILE="/tmp/run-sync-${ACCOUNT}.fails"
RCFILE="/tmp/run-sync-${ACCOUNT}.rc"
MBSYNCRC="/tmp/mbsyncrc-${ACCOUNT}"

if [ ! -f "$CRED_FILE" ]; then
  echo "[$(date)] No credentials file found for $ACCOUNT" >&2
  exit 1
fi

# Load credentials — never logged or passed as arguments
. "$CRED_FILE"
. /run/sync-config

# POST a title/body to Apprise (no-op when APPRISE_URL is unset)
notify() {
  [ -n "${APPRISE_URL:-}" ] || return 0
  wget -q -O /dev/null --header="Content-Type: application/json" \
    --post-data="{\"title\":\"$1\",\"body\":\"$2\"}" "$APPRISE_URL" 2>/dev/null \
    || echo "[$(date)] Apprise notify failed" >> "$LOGFILE"
}

# Increment a counter file and print the new value
bump() {
  n=$(( $(cat "$1" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$1"
  echo "$n"
}

# flock is released by the kernel when the process dies, however it dies,
# so a killed run can never leave a stale lock behind.
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[$(date)] Skipping: previous sync for $ACCOUNT still running" >> "$LOGFILE"
  [ "$(bump "$SKIPFILE")" -eq "${SKIP_ALERT_THRESHOLD:-6}" ] \
    && notify "imap sync STUCK: $ACCOUNT" "Skipped ${SKIP_ALERT_THRESHOLD:-6} runs in a row, a previous sync is still running."
  exit 0
fi
rm -f "$SKIPFILE"
trap 'rm -f "$MBSYNCRC" "$RCFILE"' EXIT

PATTERNS="*"
if [ -n "$EXCLUDE" ]; then
  for folder in $(echo "$EXCLUDE" | tr ',' '\n'); do
    PATTERNS="$PATTERNS !$folder"
  done
fi

cat > "$MBSYNCRC" << EOF
IMAPAccount account
Host imap.gmail.com
User $ACCOUNT
Pass $PASSWORD
TLSType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt
PipelineDepth ${PIPELINE_DEPTH:-50}

IMAPStore remote
Account account

MaildirStore local
SubFolders Verbatim
Path /data/$TARGET/
Inbox /data/$TARGET/INBOX
AltMap yes

Channel sync
Far :remote:
Near :local:
Patterns $PATTERNS
Sync Pull
Create Near
Expunge Near
SyncState *
EOF

umask 022

rotate "$LOGFILE"

mkdir -p "/data/$TARGET"
# the pipe hides mbsync's exit code, so record it in a file
{ mbsync -c "$MBSYNCRC" -Va 2>&1; echo $? > "$RCFILE"; } \
  | awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush() }' | tee -a "$LOGFILE"

RC=$(cat "$RCFILE" 2>/dev/null || echo 1)
if [ "$RC" -ne 0 ]; then
  [ "$(bump "$FAILFILE")" -eq "${FAIL_ALERT_THRESHOLD:-3}" ] \
    && notify "imap sync FAILED: $ACCOUNT" "mbsync failed ${FAIL_ALERT_THRESHOLD:-3} runs in a row (last exit code $RC). See $(basename "$LOGFILE")."
else
  rm -f "$FAILFILE"
fi

# mbsync hardcodes 0700 on Maildir dirs — fix after sync
chmod -R a+rX "/data/$TARGET"
