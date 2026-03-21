#!/bin/sh
set -e

CRON_FILE="/etc/crontabs/root"

# Strip blank lines from CRON_JOBS before writing crontab
printf "%s\n" "$CRON_JOBS" | grep -v '^[[:space:]]*$' > "$CRON_FILE"

chmod 600 "$CRON_FILE"

# Run cron in foreground; -l 8 suppresses debug noise (and passwords in command logs)
exec busybox crond -f -l 8 -L /dev/stderr -c /etc/crontabs
