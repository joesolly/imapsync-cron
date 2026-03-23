#!/bin/sh

ACCOUNT="$1"
PASSWORD="$2"
TARGET="$3"
EXCLUDE="$4"   # optional: comma-separated folders to skip, e.g. "Clubs,Forums"
LOGFILE="/var/log/cron/${ACCOUNT}.log"
LOCKFILE="/tmp/run-sync-${ACCOUNT}.lock"
MBSYNCRC="/tmp/mbsyncrc-${ACCOUNT}"

if [ -e "$LOCKFILE" ]; then
  echo "[$(date)] Skipping: previous sync for $ACCOUNT still running ($(cat $LOCKFILE))" >> "$LOGFILE"
  exit 0
fi

echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE" "$MBSYNCRC"' EXIT

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
SSLType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

IMAPStore remote
Account account

MaildirStore local
SubFolders Verbatim
Path /data/$TARGET/
Inbox /data/$TARGET/INBOX

Channel sync
Far :remote:
Near :local:
Patterns $PATTERNS
Sync Pull
Create Near
Expunge Near
SyncState *
EOF

rotate "$LOGFILE"

mkdir -p "/data/$TARGET"
mbsync -c "$MBSYNCRC" -a 2>&1 | tee -a "$LOGFILE"
