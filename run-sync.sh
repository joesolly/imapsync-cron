#!/bin/sh

ACCOUNT="$1"
PASSWORD="$2"
TARGET="$3"
LOGFILE="/var/log/cron/${ACCOUNT}.log"
LOCKFILE="/tmp/run-sync-${ACCOUNT}.lock"

if [ -e "$LOCKFILE" ]; then
  echo "[$(date)] Skipping: previous sync for $ACCOUNT still running ($(cat $LOCKFILE))" >> "$LOGFILE"
  exit 0
fi

echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

rotate "$LOGFILE"

mkdir -p "/data/$TARGET"
cd "/data/$TARGET"

imapbackup \
  --server imap.gmail.com \
  --ssl \
  --user "$ACCOUNT" \
  --pass "$PASSWORD" \
  --nospinner \
  2>&1 | tee -a "$LOGFILE"
