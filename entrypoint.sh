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

# Parse ACCOUNT_* env vars (format: email|password|target|schedule[|exclude])
# Write credentials files and build crontab — passwords never enter the crontab
printenv | grep '^ACCOUNT_' | while IFS='=' read -r key value; do
  email=$(echo "$value"    | cut -d'|' -f1)
  password=$(echo "$value" | cut -d'|' -f2)
  target=$(echo "$value"   | cut -d'|' -f3)
  schedule=$(echo "$value" | cut -d'|' -f4)
  exclude=$(echo "$value"  | cut -d'|' -f5)

  # Write credentials file readable only by the sync user
  cred_file="$CREDENTIALS_DIR/$email"
  printf 'PASSWORD=%s\nTARGET=%s\nEXCLUDE=%s\n' "$password" "$target" "$exclude" > "$cred_file"
  chmod 600 "$cred_file"

  # Add cron entry — no password
  echo "$schedule run-sync $email" >> "$CRON_FILE"
done

chmod 600 "$CRON_FILE"

# Run cron in foreground as the target user via su-exec
exec su-exec "$CRON_USER" busybox crond -f -l 8 -L /dev/stderr -c /etc/crontabs
