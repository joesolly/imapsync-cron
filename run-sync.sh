#!/bin/sh

ACCOUNT="$1"
PASSWORD="$2"
TARGET="$3"
LOGFILE="/var/log/cron/${ACCOUNT}.log"

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
