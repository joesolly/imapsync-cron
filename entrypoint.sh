#!/bin/sh
set -e

PUID=${PUID:-0}
PGID=${PGID:-0}

if [ "$PUID" != "0" ] || [ "$PGID" != "0" ]; then
  addgroup -g "$PGID" syncuser 2>/dev/null || true
  adduser -D -u "$PUID" -G syncuser syncuser 2>/dev/null || true
  CRON_FILE="/etc/crontabs/syncuser"
else
  CRON_FILE="/etc/crontabs/root"
fi

# Strip blank lines from CRON_JOBS before writing crontab
printf "%s\n" "$CRON_JOBS" | grep -v '^[[:space:]]*$' > "$CRON_FILE"

chmod 600 "$CRON_FILE"

# Run cron in foreground; -l 8 suppresses debug noise (and passwords in command logs)
exec busybox crond -f -l 8 -L /dev/stderr -c /etc/crontabs
