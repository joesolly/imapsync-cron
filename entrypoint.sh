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

# Strip blank lines from CRON_JOBS before writing crontab
printf "%s\n" "$CRON_JOBS" | grep -v '^[[:space:]]*$' > "$CRON_FILE"
chmod 600 "$CRON_FILE"

# Run cron in foreground as the target user via su-exec
exec su-exec "$CRON_USER" busybox crond -f -l 8 -L /dev/stderr -c /etc/crontabs
