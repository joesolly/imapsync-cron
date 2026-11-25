#!/bin/sh
set -e

PUID=${PUID:-0}
PGID=${PGID:-0}

if [ "$PUID" != "0" ] || [ "$PGID" != "0" ]; then
  addgroup -g "$PGID" syncuser 2>/dev/null || true
  adduser -D -u "$PUID" -G syncuser syncuser 2>/dev/null || true
  CRON_USER="syncuser"
else
  CRON_USER="root"
fi

CRON_FILE="/etc/crontabs/${CRON_USER}"
# Clear any default Alpine crontab entries
printf '' > "$CRON_FILE"

CREDENTIALS_DIR="/run/credentials"
mkdir -p "$CREDENTIALS_DIR"

printf "PIPELINE_DEPTH=%s\nAPPRISE_URL='%s'\nSKIP_ALERT_THRESHOLD=%s\nFAIL_ALERT_THRESHOLD=%s\n" \
  "${PIPELINE_DEPTH:-50}" "${APPRISE_URL:-}" "${SKIP_ALERT_THRESHOLD:-6}" "${FAIL_ALERT_THRESHOLD:-3}" > /run/sync-config

# Single-quote a value so the credentials file can be sourced safely
# whatever characters it holds (spaces, quotes, parentheses, $ ...)
q() { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }

# Parse ACCOUNT_* env vars (format: email|password|target|schedule[|exclude])
# Write credentials files and build crontab — passwords never enter the crontab
printenv | grep '^ACCOUNT_' | while IFS='=' read -r key value; do
  email=$(printf '%s\n' "$value"    | cut -d'|' -f1)
  password=$(printf '%s\n' "$value" | cut -d'|' -f2)
  target=$(printf '%s\n' "$value"   | cut -d'|' -f3)
  schedule=$(printf '%s\n' "$value" | cut -d'|' -f4)
  exclude=$(printf '%s\n' "$value"  | cut -d'|' -f5)

  # Write credentials file readable only by the sync user
  cred_file="$CREDENTIALS_DIR/$email"
  printf 'PASSWORD=%s\nTARGET=%s\nEXCLUDE=%s\n' "$(q "$password")" "$(q "$target")" "$(q "$exclude")" > "$cred_file"
  chmod 600 "$cred_file"

  # Add cron entry — no password
  echo "$schedule run-sync $email" >> "$CRON_FILE"
done

chmod 600 "$CRON_FILE"

# Run cron in foreground as the target user via su-exec
exec su-exec "$CRON_USER" busybox crond -f -l 8 -L /dev/stderr -c /etc/crontabs
